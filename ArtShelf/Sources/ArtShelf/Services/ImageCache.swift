import AppKit
import Foundation
import ImageIO

/// 全局图片缓存——按「路径@目标尺寸」缓存缩小解码后的封面图。
///
/// 背景：封面原图常为 1000-3000px 的大图，若在 SwiftUI body 求值路径中
/// 每次都用 NSImage(contentsOfFile:) 全尺寸同步解码，单张耗时 50-200ms，
/// 网格滚动会明显卡顿。本类用 ImageIO 一次性解码出目标尺寸的缩略图并缓存，
/// 之后同一路径、同一尺寸直接命中缓存，零磁盘 I/O。
final class ImageCache: @unchecked Sendable {

    /// 全局共享实例——NSCache 本身线程安全，可在后台队列调用
    static let shared = ImageCache()

    private let cache = NSCache<NSString, NSImage>()

    /// 异步解码专用并发队列——配合信号量把同时进行的解码限制在 3 路，
    /// 避免快速滚动时几十个 cell 同时读盘 + ImageIO 解码抢占 CPU 拖慢主线程
    private let decodeQueue = DispatchQueue(
        label: "com.artshelf.ImageCache.decode",
        qos: .userInitiated,
        attributes: .concurrent
    )

    /// 同时进行的解码任务上限（磁盘读 + ImageIO 解码均为 CPU/IO 密集，
    /// 3 路并行已能打满吞吐，更多只会互相抢线程）
    private let decodeSemaphore = DispatchSemaphore(value: 3)

    /// 保护 pendingRequests 的锁
    private let requestLock = NSLock()

    /// 进行中的异步解码请求（按缓存 key 合并）：同一「路径@尺寸」只解码一次，
    /// 先到者发起解码，后到者挂到同一组等待者上，解码完成后一次性恢复
    private var pendingRequests: [NSString: [CheckedContinuation<NSImage?, Never>]] = [:]

    private init() {
        cache.countLimit = 300
        // 内存成本按像素字节计（RGBA 每像素 4 字节），约 256MB
        cache.totalCostLimit = 256 * 1024 * 1024
    }

    /// 异步取图：缓存命中立即返回（零磁盘 I/O）；未命中走有界并发队列解码并写缓存。
    /// 同一「路径+尺寸」的并发请求自动合并为一次解码。
    /// 供视图在 .task 中调用——替代各自 Task.detached 的无限并发模式。
    func imageAsync(atPath path: String, maxPixelSize: Int) async -> NSImage? {
        let key = cacheKey(path: path, maxPixelSize: maxPixelSize)
        // 缓存命中：零开销直接返回
        if let cached = cache.object(forKey: key) {
            return cached
        }

        return await withCheckedContinuation { continuation in
            var shouldDecode = false

            requestLock.lock()
            if let existing = pendingRequests[key] {
                // 已有同 key 请求进行中：合并等待，不重复解码
                pendingRequests[key] = existing + [continuation]
            } else {
                // 首个请求者：登记并负责发起解码
                pendingRequests[key] = [continuation]
                shouldDecode = true
            }
            requestLock.unlock()

            guard shouldDecode else { return }

            decodeQueue.async {
                // 有界并发：同时最多 3 个解码任务
                self.decodeSemaphore.wait()
                defer { self.decodeSemaphore.signal() }
                let image = self.image(atPath: path, maxPixelSize: maxPixelSize)

                // 取出该 key 的全部等待者并一次性恢复（含发起者自己）
                self.requestLock.lock()
                let waiters = self.pendingRequests.removeValue(forKey: key) ?? []
                self.requestLock.unlock()

                for waiter in waiters {
                    waiter.resume(returning: image)
                }
            }
        }
    }

    /// 获取指定路径图片的缩小解码版本。
    /// 命中缓存直接返回；未命中用 ImageIO 缩小解码后写入缓存。
    /// 线程安全，可在后台队列调用；极端情况下并发未命中同一 key 时
    /// 各解码各的，后写入者覆盖先写入者，不影响正确性。
    func image(atPath path: String, maxPixelSize: Int) -> NSImage? {
        let key = cacheKey(path: path, maxPixelSize: maxPixelSize)
        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard maxPixelSize > 0,
              let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let cgImage = decodeThumbnail(from: source, maxPixelSize: maxPixelSize) else {
            return nil
        }

        let image = NSImage(cgImage: cgImage, size: .zero)
        // 内存成本按像素字节计，供 NSCache 淘汰时参考
        let cost = cgImage.width * cgImage.height * 4
        cache.setObject(image, forKey: key, cost: cost)
        return image
    }

    /// 仅查询缓存、不做磁盘解码——供需要在展示求值路径里同步查询的视图使用
    /// （如 CoverImageView 在 body 里先查一次，命中即零成本直接展示）。
    func cachedImage(atPath path: String, maxPixelSize: Int) -> NSImage? {
        cache.object(forKey: cacheKey(path: path, maxPixelSize: maxPixelSize))
    }

    /// 用 ImageIO 缩小解码：按 maxPixelSize 限制只解出所需数据量，
    /// 避免整幅大图先全量解码再缩放占内存
    private func decodeThumbnail(from source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            // 原图没有内嵌缩略图时也从完整图缩小解码
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // 立即把解码结果驻留内存，避免稍后按需重解
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// 缓存 key：路径 + 目标尺寸，不同尺寸的缩略图互不串用
    private func cacheKey(path: String, maxPixelSize: Int) -> NSString {
        "\(path)@\(maxPixelSize)" as NSString
    }
}