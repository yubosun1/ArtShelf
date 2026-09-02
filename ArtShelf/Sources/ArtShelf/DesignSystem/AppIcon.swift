import SwiftUI
import AppKit

/// 可选应用图标（Resources/Icons 下的 PNG，设置内自由切换）
///
/// 切换机制沿用 v2：`NSApplication.shared.applicationIconImage` 动态替换，
/// 选择持久化到 UserDefaults（键 `appIcon`），启动时由 `ThemeSettings.applyAppearance()` 一并应用。
/// 默认「象牙画廊」即系统 icns 同款图标——随时切回即完成回退。
enum AppIconOption: String, CaseIterable, Identifiable {
    case ivory = "prism_ivory"
    case sky = "prism_sky"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ivory: return "象牙画廊"
        case .sky:   return "晴空微晶"
        }
    }

    /// 图标图片：① App Bundle 的 Resources/Icons；② 开发期相对路径（`swift run`）；③ 回退当前应用图标
    @MainActor
    var image: NSImage? {
        let filename = "\(rawValue).png"

        if let url = Bundle.main.url(forResource: rawValue, withExtension: "png", subdirectory: "Icons"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        if let url = Bundle.main.url(forResource: rawValue, withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }

        let candidates = [
            "Resources/Icons/\(filename)",
            "ArtShelf/Resources/Icons/\(filename)",
            "../Resources/Icons/\(filename)",
            "../../Resources/Icons/\(filename)"
        ]
        for rel in candidates {
            let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(rel)
            if FileManager.default.fileExists(atPath: url.path), let img = NSImage(contentsOf: url) {
                return img
            }
        }

        return NSApplication.shared.applicationIconImage
    }

    /// 应用到 Dock / 应用图标
    @MainActor
    func apply() {
        guard let image else { return }
        NSApplication.shared.applicationIconImage = image
    }
}
