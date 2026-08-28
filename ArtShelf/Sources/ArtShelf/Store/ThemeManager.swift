import SwiftUI
import AppKit

/// 外观模式
enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light:  return "浅色模式"
        case .dark:   return "深色模式"
        }
    }

    var iconName: String {
        switch self {
        case .system: return "laptopcomputer"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.stars.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// 可选应用图标
enum AppIconOption: String, CaseIterable, Identifiable {
    case ivory = "prism_ivory"
    case sky   = "prism_sky"
    case rose  = "prism_rose"
    case dark  = "prism_dark"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ivory: return "象牙画廊纯白"
        case .sky:   return "晴空微晶淡蓝"
        case .rose:  return "珍珠粉晕暖白"
        case .dark:  return "深空暮夜棱镜"
        }
    }

    var subtitle: String {
        switch self {
        case .ivory: return "纯净画廊美学，通透水晶棱镜折射光谱"
        case .sky:   return "清爽晴空冰晶呼吸感，轻盈明亮"
        case .rose:  return "温柔治愈粉白微晕，契合女团追星与审美"
        case .dark:  return "沉稳暮夜黑曜石，沉浸式深空质感"
        }
    }

    var isLight: Bool {
        self != .dark
    }

    /// 获取图标图片
    var image: NSImage? {
        let filename = "\(rawValue).png"

        // 1. 尝试从 App Bundle 的 Resources/Icons 目录加载
        if let bundleURL = Bundle.main.url(forResource: rawValue, withExtension: "png", subdirectory: "Icons"),
           let img = NSImage(contentsOf: bundleURL) {
            return img
        }

        if let bundleDirectURL = Bundle.main.url(forResource: rawValue, withExtension: "png"),
           let img = NSImage(contentsOf: bundleDirectURL) {
            return img
        }

        // 2. 尝试从当前运行目录下的 Resources/Icons 加载（适配命令行/开发阶段）
        let candidates = [
            "Resources/Icons/\(filename)",
            "ArtShelf/Resources/Icons/\(filename)",
            "../Resources/Icons/\(filename)",
            "../../Resources/Icons/\(filename)"
        ]

        for relPath in candidates {
            let fullURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(relPath)
            if FileManager.default.fileExists(atPath: fullURL.path),
               let img = NSImage(contentsOf: fullURL) {
                return img
            }
        }

        // 3. 回退为当前应用默认图标
        return NSApplication.shared.applicationIconImage
    }
}

/// 主题与图标全局管理器
final class ThemeManager: ObservableObject {

    static let shared = ThemeManager()

    private let appearanceKey = "artshelf_app_appearance"
    private let iconKey = "artshelf_selected_app_icon"

    @Published var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: appearanceKey)
        }
    }

    @Published var selectedIcon: AppIconOption {
        didSet {
            UserDefaults.standard.set(selectedIcon.rawValue, forKey: iconKey)
            applyIcon(selectedIcon)
        }
    }

    init() {
        // 读取存储的外观
        let savedAppearanceRaw = UserDefaults.standard.string(forKey: appearanceKey) ?? AppAppearance.system.rawValue
        self.appearance = AppAppearance(rawValue: savedAppearanceRaw) ?? .system

        // 读取存储的图标
        let savedIconRaw = UserDefaults.standard.string(forKey: iconKey) ?? AppIconOption.ivory.rawValue
        let icon = AppIconOption(rawValue: savedIconRaw) ?? .ivory
        self.selectedIcon = icon

        // 立即应用当前图标
        DispatchQueue.main.async {
            self.applyIcon(icon)
        }
    }

    /// 应用选中的应用图标
    func applyIcon(_ icon: AppIconOption) {
        guard let img = icon.image else { return }
        NSApplication.shared.applicationIconImage = img
    }
}
