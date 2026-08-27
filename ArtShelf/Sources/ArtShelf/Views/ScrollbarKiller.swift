import AppKit
import SwiftUI
import ObjectiveC.runtime

/// 物理级全局抹除 macOS 所有滚动条与滚动轨槽 (Total Scrollbar & Track Annihilation)
enum ScrollbarKiller {

    static func install() {
        _ = swizzleOnce
    }

    private static let swizzleOnce: Void = {
        let cls: AnyClass = NSScroller.self

        // 1. 强制 isHidden 恒为 true
        if let orig = class_getInstanceMethod(cls, #selector(getter: NSView.isHidden)),
           let swiz = class_getInstanceMethod(cls, #selector(getter: NSScroller.art_isHidden)) {
            method_exchangeImplementations(orig, swiz)
        }

        // 2. 强制 draw(_:) 为空操作（绝不绘制任何滑块、轨道、槽阴影）
        if let orig = class_getInstanceMethod(cls, #selector(NSView.draw(_:))),
           let swiz = class_getInstanceMethod(cls, #selector(NSScroller.art_draw(_:))) {
            method_exchangeImplementations(orig, swiz)
        }

        // 3. 强制 scrollerWidth 恒为 0（彻底消除 Legacy 模式下占用的 15px 灰底轨槽与空白道）
        if let orig = class_getClassMethod(cls, #selector(NSScroller.scrollerWidth(for:scrollerStyle:))),
           let swiz = class_getClassMethod(cls, #selector(NSScroller.art_scrollerWidth(for:scrollerStyle:))) {
            method_exchangeImplementations(orig, swiz)
        }

        // 4. 强制 drawKnob() 为空操作
        if let orig = class_getInstanceMethod(cls, #selector(NSScroller.drawKnob)),
           let swiz = class_getInstanceMethod(cls, #selector(NSScroller.art_drawKnob)) {
            method_exchangeImplementations(orig, swiz)
        }

        // 5. 强制 drawKnobSlot 为空操作
        if let orig = class_getInstanceMethod(cls, #selector(NSScroller.drawKnobSlot(in:highlight:))),
           let swiz = class_getInstanceMethod(cls, #selector(NSScroller.art_drawKnobSlot(in:highlight:))) {
            method_exchangeImplementations(orig, swiz)
        }
    }()
}

private extension NSScroller {
    @objc dynamic var art_isHidden: Bool {
        return true
    }

    @objc dynamic func art_draw(_ dirtyRect: NSRect) {
        // 彻底静默：不画轨道，不画槽位，不画任何底色
    }

    @objc dynamic func art_drawKnob() {
        // 彻底静默：不画滑块
    }

    @objc dynamic func art_drawKnobSlot(in slotRect: NSRect, highlight: Bool) {
        // 彻底静默：不画槽位
    }

    @objc dynamic class func art_scrollerWidth(for controlSize: NSControl.ControlSize, scrollerStyle: NSScroller.Style) -> CGFloat {
        return 0
    }
}

/// 窗口级深层遍历抹除器
struct WindowScrollbarKiller: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            stripRecursively(from: view.window?.contentView)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            stripRecursively(from: nsView.window?.contentView)
        }
    }

    private func stripRecursively(from view: NSView?) {
        guard let view = view else { return }
        if let sv = view as? NSScrollView {
            sv.hasVerticalScroller = false
            sv.hasHorizontalScroller = false
            sv.verticalScroller?.isHidden = true
            sv.horizontalScroller?.isHidden = true
            sv.verticalScroller = nil
            sv.horizontalScroller = nil
            sv.autohidesScrollers = true
            sv.scrollerStyle = .overlay
            sv.scrollerInsets = NSEdgeInsetsZero
        }
        for sub in view.subviews {
            stripRecursively(from: sub)
        }
    }
}
