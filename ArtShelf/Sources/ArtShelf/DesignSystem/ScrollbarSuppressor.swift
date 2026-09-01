import SwiftUI
import AppKit

/// 全局滚动条净化器（macOS 兜底）
///
/// 实测 SwiftUI 的 `.scrollIndicators(.hidden)` 在本机 macOS 上对部分
/// `NSScrollView`（详情页右栏、TextEditor 内置滚动等）不生效，故用 AppKit 层强制：
/// - 视图挂到窗口（`didMoveToWindow`）时立即**同步**关闭滚动条，首帧即不可见；
/// - 对每个 `NSScrollView` 挂 KVO 监听 `hasVerticalScroller` / `hasHorizontalScroller`：
///   SwiftUI 若因内容变化重新打开滚动条，在被渲染前即刻收回（无闪烁）；
/// - 0.5 秒低频遍历兜住未触发的边角情况。
///
/// 只做属性赋值与 KVO，不 swizzle、不改系统全局设置（此前 swizzle 方案曾导致空窗口，勿再引入）。
@MainActor
final class ScrollbarSanitizer: NSObject {

    static let shared = ScrollbarSanitizer()

    /// 已挂 KVO 的滚动视图，避免重复注册（NSScrollView 生命周期与 App 一致，无需移除）
    private var observed = Set<ObjectIdentifier>()
    private var installed = false
    private var safetyTimer: Timer?

    func install() {
        guard !installed else { return }
        installed = true
        let nc = NotificationCenter.default
        // SwiftUI 每次布局都会设置视图 bounds：沿父链找到宿主 NSScrollView 即刻清除
        nc.addObserver(self, selector: #selector(boundsChanged(_:)), name: NSView.boundsDidChangeNotification, object: nil)
        nc.addObserver(self, selector: #selector(windowChanged(_:)), name: NSWindow.didResizeNotification, object: nil)
        nc.addObserver(self, selector: #selector(windowChanged(_:)), name: NSWindow.didUpdateNotification, object: nil)

        // 低频安全网：正常路径由 boundsDidChange + KVO 即时处理，此处兜住边角情况
        let timer = Timer(timeInterval: 0.5, repeats: true) { _ in
            MainActor.assumeIsolated {
                for window in NSApp.windows {
                    Self.discover(window.contentView)
                }
            }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        safetyTimer = timer
    }

    /// 任意视图边界变化时，沿父链找宿主 NSScrollView（滚动视图创建 / 布局的瞬间即清除）
    @objc private func boundsChanged(_ note: Notification) {
        guard let view = note.object as? NSView else { return }
        var node: NSView? = view
        while let current = node {
            if let scroll = current as? NSScrollView {
                Self.attach(scroll)
                return
            }
            node = current.superview
        }
    }

    @objc private func windowChanged(_ note: Notification) {
        guard let window = note.object as? NSWindow else { return }
        Self.discover(window.contentView)
    }

    /// 遍历视图树：找到 NSScrollView 立即关闭滚动条并挂 KVO 自愈
    @MainActor
    static func discover(_ view: NSView?) {
        guard let view else { return }
        if let scroll = view as? NSScrollView {
            Self.attach(scroll)
        }
        for subview in view.subviews {
            discover(subview)
        }
    }

    @MainActor
    private static func attach(_ scroll: NSScrollView) {
        let sanitizer = ScrollbarSanitizer.shared
        if sanitizer.observed.insert(ObjectIdentifier(scroll)).inserted {
            scroll.addObserver(sanitizer, forKeyPath: "hasVerticalScroller", options: [], context: nil)
            scroll.addObserver(sanitizer, forKeyPath: "hasHorizontalScroller", options: [], context: nil)
        }
        // 带值判断：避免相同值赋值触发 KVO 无限循环
        if scroll.hasVerticalScroller { scroll.hasVerticalScroller = false }
        if scroll.hasHorizontalScroller { scroll.hasHorizontalScroller = false }
    }

    /// SwiftUI 打开滚动条的瞬间同步收回（只做值变化时的赋值，避免与自身递归）
    nonisolated override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        // 不捕获 nonisolated 入参（Swift 6 发送检查）；无论哪个滚动视图变化，全量复查一次即可
        MainActor.assumeIsolated {
            for window in NSApp.windows {
                Self.discover(window.contentView)
            }
        }
    }
}

/// 挂到视图树根部：安装一次净化器（覆盖所有窗口、Sheet、Popover）
struct WindowScrollbarSuppressor: NSViewRepresentable {

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        ScrollbarSanitizer.shared.install()
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // 布局更新后再兜一轮
        DispatchQueue.main.async {
            ScrollbarSanitizer.discover(nsView.window?.contentView)
        }
    }

    final class Coordinator {}
}

extension View {
    /// 隐藏应用中所有滚动条的系统级兜底（含 Sheet / Popover 中的滚动视图）
    func suppressAllScrollbars() -> some View {
        background(WindowScrollbarSuppressor())
    }
}
