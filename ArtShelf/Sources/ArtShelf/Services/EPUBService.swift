import CoreFoundation
import Foundation
import os

/// EPUB 封面提取服务
/// 使用 Swift 原生字符串匹配，避免 NSRegularExpression 在后台线程抛出 Obj-C 异常
final class EPUBService: Sendable {

    static let shared = EPUBService()

    /// 日志（subsystem 统一为 "ArtShelf"，category 为类名）
    private static let logger = Logger(subsystem: "ArtShelf", category: "EPUBService")

    private init() {}

    // MARK: - 异步提取（主线程调用）

    /// 异步提取（主线程调用）。
    /// 用一个非结构化任务包装同步的 extractCover；取消经 withTaskCancellationHandler
    /// 显式转发给内部任务，父任务取消后 extractCover 在关键节点检查 Task.isCancelled
    /// 放弃，不再继续解压写盘。
    func extractCoverAsync(from epubPath: String) async -> String? {
        let task = Task(priority: .userInitiated) {
            self.extractCover(from: epubPath)
        }
        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    // MARK: - 同步提取（后台线程调用）

    func extractCover(from epubPath: String) -> String? {
        guard FileManager.default.fileExists(atPath: epubPath) else {
            Self.logger.error("EPUB 文件不存在: \(epubPath, privacy: .public)")
            return nil
        }

        // 关键节点检查取消：父任务取消后立即放弃，不继续解压写盘
        if Task.isCancelled { return nil }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArtShelfEPUB_\(UUID().uuidString)")

        guard unzip(at: epubPath, to: tempDir) else {
            Self.logger.error("EPUB 解压失败: \(epubPath, privacy: .public)")
            try? FileManager.default.removeItem(at: tempDir)
            return nil
        }
        defer { try? FileManager.default.removeItem(at: tempDir) }

        if Task.isCancelled { return nil }

        guard let coverRelativePath = findCoverImagePath(in: tempDir) else {
            Self.logger.error("未能在 EPUB 中定位封面图: \(epubPath, privacy: .public)")
            return nil
        }

        let coverURL = tempDir.appendingPathComponent(coverRelativePath)
        guard FileManager.default.fileExists(atPath: coverURL.path) else {
            Self.logger.debug("EPUB 封面文件缺失: \(coverURL.path, privacy: .public)")
            return nil
        }

        guard let imageData = try? Data(contentsOf: coverURL) else {
            Self.logger.error("读取 EPUB 封面数据失败: \(coverURL.path, privacy: .public)")
            return nil
        }

        if Task.isCancelled { return nil }

        // OPF 内 item 的扩展名不可信（可能指向 .xhtml 等），先按数据魔数确定实际格式
        let ext = Self.imageFileExtension(for: imageData, fallback: coverURL.pathExtension)
        let coverFile = LibraryPaths.coversDirectory
            .appendingPathComponent("\(UUID().uuidString).\(ext)")
        do {
            try imageData.write(to: coverFile)
        } catch {
            Self.logger.error("保存 EPUB 封面失败: \(error, privacy: .public)")
            return nil
        }

        // 写盘后若任务已被取消：清理刚写出的封面，避免留下孤儿文件
        if Task.isCancelled {
            try? FileManager.default.removeItem(at: coverFile)
            return nil
        }
        return coverFile.path
    }

    // MARK: - 图片格式嗅探

    /// 按魔数嗅探图片实际格式决定扩展名（JPEG=FF D8 FF，PNG=89 50 4E 47，
    /// GIF=47 49 46 38，WebP=RIFF????WEBP，BMP=42 4D）；
    /// 嗅探不到时回退 href 原扩展名（限白名单），白名单外统一用 jpg
    private static func imageFileExtension(for data: Data, fallback: String) -> String {
        let prefix = [UInt8](data.prefix(16))
        if prefix.count >= 3, prefix[0] == 0xFF, prefix[1] == 0xD8, prefix[2] == 0xFF { return "jpg" }
        if prefix.count >= 4, prefix[0] == 0x89, prefix[1] == 0x50, prefix[2] == 0x4E, prefix[3] == 0x47 { return "png" }
        if prefix.count >= 4, prefix[0] == 0x47, prefix[1] == 0x49, prefix[2] == 0x46, prefix[3] == 0x38 { return "gif" }
        if prefix.count >= 12, prefix[0] == 0x52, prefix[1] == 0x49, prefix[2] == 0x46, prefix[3] == 0x46,
           prefix[8] == 0x57, prefix[9] == 0x45, prefix[10] == 0x42, prefix[11] == 0x50 { return "webp" }
        if prefix.count >= 2, prefix[0] == 0x42, prefix[1] == 0x4D { return "bmp" }

        let allowed: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "bmp"]
        let lower = fallback.lowercased()
        return allowed.contains(lower) ? lower : "jpg"
    }

    // MARK: - 解压

    private func unzip(at epubPath: String, to destinationURL: URL) -> Bool {
        try? FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", "-q", epubPath, "-d", destinationURL.path]

        // 输出重定向到 nullDevice：unzip -q 输出量小且无需读取，
        // 避免管道缓冲区写满后进程阻塞
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()

            // 轮询等待，30 秒超时；父任务取消时提前终止解压进程，尽早停止写盘
            let deadline = Date().addingTimeInterval(30)
            while process.isRunning && Date() < deadline {
                if Task.isCancelled {
                    process.terminate()
                    Thread.sleep(forTimeInterval: 0.5)
                    return false
                }
                Thread.sleep(forTimeInterval: 0.2)
            }

            if process.isRunning {
                process.terminate()
                Thread.sleep(forTimeInterval: 0.5)
                return false
            }

            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - 查找封面图

    /// 解码 EPUB 内 XML 文本：部分中文 EPUB 使用 GBK / UTF-16 编码，
    /// 依次尝试 UTF-8 → UTF-16 → GB18030，避免仅按 UTF-8 解码失败而丢封面
    private func decodeXMLText(_ data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .utf16) { return text }
        let gb18030 = String.Encoding(rawValue: UInt(CFStringEncodings.GB_18030_2000.rawValue))
        return String(data: data, encoding: gb18030)
    }

    private func findCoverImagePath(in rootDir: URL) -> String? {
        // 1. 读取 META-INF/container.xml
        let containerURL = rootDir.appendingPathComponent("META-INF/container.xml")
        guard let containerData = try? Data(contentsOf: containerURL),
              let containerXML = decodeXMLText(containerData) else {
            return nil
        }

        guard let opfRelativePath = extractAttribute(from: containerXML, attribute: "full-path") else {
            return nil
        }

        // 2. 读取 OPF 文件
        let opfURL = rootDir.appendingPathComponent(opfRelativePath)
        guard let opfData = try? Data(contentsOf: opfURL),
              let opfXML = decodeXMLText(opfData) else {
            return nil
        }

        let opfDir = opfURL.deletingLastPathComponent()

        // 3. 策略 A: properties="cover-image"
        if let path = findCoverByProperty(in: opfXML, opfDir: opfDir, rootDir: rootDir) {
            return path
        }

        // 4. 策略 B: meta name="cover"
        if let path = findCoverByMetaName(in: opfXML, opfDir: opfDir, rootDir: rootDir) {
            return path
        }

        // 5. 策略 C: 启发式
        if let path = findCoverByHeuristic(in: opfXML, opfDir: opfDir, rootDir: rootDir) {
            return path
        }

        return nil
    }

    // MARK: - 策略 A: properties="cover-image"

    private func findCoverByProperty(in opfXML: String, opfDir: URL, rootDir: URL) -> String? {
        // 查找包含 properties="...cover-image..." 的 <item> 标签，提取 href
        let items = extractAllTags(named: "item", from: opfXML)
        for item in items {
            if let props = extractAttribute(from: item, attribute: "properties"),
               props.lowercased().contains("cover-image") {
                if let href = extractAttribute(from: item, attribute: "href") {
                    if let resolved = resolveRelativePath(href, opfDir: opfDir, rootDir: rootDir) {
                        return resolved
                    }
                }
            }
        }
        return nil
    }

    // MARK: - 策略 B: meta name="cover"

    private func findCoverByMetaName(in opfXML: String, opfDir: URL, rootDir: URL) -> String? {
        // 查找 <meta name="cover" content="cover-id" />
        let metas = extractAllTags(named: "meta", from: opfXML)
        for meta in metas {
            if let name = extractAttribute(from: meta, attribute: "name"),
               name.lowercased() == "cover",
               let coverId = extractAttribute(from: meta, attribute: "content") {
                // 在 <item> 中找 id="coverId" 的图片
                let items = extractAllTags(named: "item", from: opfXML)
                for item in items {
                    if let id = extractAttribute(from: item, attribute: "id"),
                       id == coverId {
                        if let href = extractAttribute(from: item, attribute: "href") {
                            if let resolved = resolveRelativePath(href, opfDir: opfDir, rootDir: rootDir) {
                                return resolved
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    // MARK: - 策略 C: 启发式

    private func findCoverByHeuristic(in opfXML: String, opfDir: URL, rootDir: URL) -> String? {
        let items = extractAllTags(named: "item", from: opfXML)

        // 优先找 id 或 href 中包含 "cover" 的图片
        var fallbackImageItems: [(href: String, id: String)] = []

        for item in items {
            guard let mediaType = extractAttribute(from: item, attribute: "media-type"),
                  mediaType.hasPrefix("image/"),
                  let href = extractAttribute(from: item, attribute: "href") else {
                continue
            }

            let id = extractAttribute(from: item, attribute: "id") ?? ""
            let idLower = id.lowercased()
            let hrefLower = href.lowercased()

            if idLower.contains("cover") || hrefLower.contains("cover") {
                if let resolved = resolveRelativePath(href, opfDir: opfDir, rootDir: rootDir) {
                    return resolved
                }
            }

            fallbackImageItems.append((href: href, id: id))
        }

        // 最后兜底：取第一个图片 item
        for item in fallbackImageItems {
            if let resolved = resolveRelativePath(item.href, opfDir: opfDir, rootDir: rootDir) {
                return resolved
            }
        }

        return nil
    }

    // MARK: - Swift 原生 XML 解析工具

    /// 从 XML 字符串中提取指定属性的值（使用 Swift 原生字符串匹配，避免 Obj-C 异常）
    /// 兼容双引号与单引号两种写法（部分 EPUB 的 OPF 文件使用单引号）
    private func extractAttribute(from xml: String, attribute: String) -> String? {
        // 查找 attribute= 后跟引号包裹的值
        let pattern = "\(attribute)="
        guard let patternRange = xml.range(of: pattern, options: .caseInsensitive) else {
            return nil
        }

        let valueStart = patternRange.upperBound
        let remaining = xml[valueStart...]

        // XML 属性必须带引号（双引号或单引号均可）
        guard let quote = remaining.first, quote == "\"" || quote == "'" else {
            return nil
        }

        // 找到与开头配对的闭合引号
        let afterQuote = remaining.index(after: remaining.startIndex)
        guard let endQuote = remaining[afterQuote...].firstIndex(of: quote) else {
            return nil
        }

        return String(remaining[afterQuote..<endQuote])
    }

    /// 提取所有指定标签名的标签（包括自闭合和非自闭合）
    /// 返回每个标签的完整字符串（如 `<item id="x" href="y" />`）
    private func extractAllTags(named tagName: String, from xml: String) -> [String] {
        var results: [String] = []
        let openTag = "<\(tagName)"
        let closeTag = "</\(tagName)>"
        let selfClose = "/>"

        var searchRange = xml.startIndex..<xml.endIndex

        while let openRange = xml.range(of: openTag, options: .caseInsensitive, range: searchRange) {
            let afterOpen = openRange.upperBound

            // 尝试找自闭合标签结束位置 />
            if let selfCloseRange = xml.range(of: selfClose, options: .caseInsensitive, range: afterOpen..<xml.endIndex) {
                // 检查中间没有 > (确保是同一个标签)
                let tagContent = xml[openRange.lowerBound..<selfCloseRange.upperBound]
                if !tagContent.contains(">") || tagContent.range(of: ">", options: .caseInsensitive, range: tagContent.startIndex..<tagContent.range(of: selfClose)!.lowerBound) == nil {
                    results.append(String(tagContent))
                    searchRange = selfCloseRange.upperBound..<xml.endIndex
                    continue
                }
            }

            // 尝试找非自闭合标签结束位置 >
            if let closeAngle = xml.range(of: ">", range: afterOpen..<xml.endIndex) {
                // 检查是否是 <tag ...> 形式（非自闭合）
                let tagContent = String(xml[openRange.lowerBound..<closeAngle.upperBound])

                // 如果标签里有 /> 在 > 之前，说明是自闭合
                if tagContent.contains("/>") {
                    // 已经在上面处理了，跳过
                    searchRange = closeAngle.upperBound..<xml.endIndex
                    continue
                }

                // 非自闭合标签：找 </tagName>
                if let endRange = xml.range(of: closeTag, options: .caseInsensitive, range: closeAngle.upperBound..<xml.endIndex) {
                    let fullTag = String(xml[openRange.lowerBound..<endRange.upperBound])
                    results.append(fullTag)
                    searchRange = endRange.upperBound..<xml.endIndex
                    continue
                }
            }

            searchRange = afterOpen..<xml.endIndex
        }

        return results
    }

    // MARK: - 路径解析

    private func resolveRelativePath(_ href: String, opfDir: URL, rootDir: URL) -> String? {
        let decoded = href.removingPercentEncoding ?? href

        // 安全地构造路径（避免 Obj-C 异常）
        let opfDirPath = opfDir.path
        let fullPath = (opfDirPath as NSString).appendingPathComponent(decoded)

        // 越界防护：href 含 ../ 时可解析到解压目录之外，读到共享临时目录中的同名文件。
        // 标准化后必须仍位于解压根目录内，否则视为无效路径（合法的 ../ 仍放行）
        let standardized = URL(fileURLWithPath: fullPath).standardizedFileURL.path
        let rootStandardized = rootDir.standardizedFileURL.path
        guard standardized == rootStandardized || standardized.hasPrefix(rootStandardized + "/") else {
            return nil
        }

        // 转换为相对于 rootDir 的路径
        let rootPath = rootDir.path
        guard let relative = relativePath(from: fullPath, to: rootPath) else {
            if FileManager.default.fileExists(atPath: fullPath) {
                return decoded
            }
            return nil
        }

        let checkPath = (rootPath as NSString).appendingPathComponent(relative)
        if FileManager.default.fileExists(atPath: checkPath) {
            return relative
        }

        return nil
    }

    /// 计算相对路径
    private func relativePath(from path: String, to base: String) -> String? {
        let pathComponents = path.split(separator: "/").map(String.init)
        let baseComponents = base.split(separator: "/").map(String.init)

        var commonCount = 0
        for i in 0..<min(pathComponents.count, baseComponents.count) {
            if pathComponents[i] == baseComponents[i] {
                commonCount += 1
            } else {
                break
            }
        }

        let upCount = baseComponents.count - commonCount
        let downComponents = pathComponents[commonCount...]

        var result: [String] = []
        for _ in 0..<upCount { result.append("..") }
        result.append(contentsOf: downComponents)

        return result.joined(separator: "/")
    }
}
