import SwiftUI
import AppKit

/// 外观与主题设置（UserDefaults 持久化，全局单例）
///
/// 视图仍读 `Theme.bg` 等静态令牌——令牌改为转发到本单例的计算属性，
/// 依赖 SwiftUI Observation 的运行时追踪，切换后全部引用点自动刷新。
/// （属性读写均发生在主线程的视图求值中；类本身不隔离，
///  以便 `Theme` 的非隔离静态上下文可以直接引用。）
@Observable
final class ThemeSettings {

    /// 全局单例（非隔离不安全标注：全部读写实际都发生在主线程的视图求值中）
    nonisolated(unsafe) static let shared = ThemeSettings()

    /// 完整主题（默认跟随系统）
    var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
            let theme = theme
            Task { @MainActor in
                NSApplication.shared.appearance = theme.nsAppearance
            }
        }
    }

    /// 应用图标（默认象牙画廊，即系统 icns 同款）
    var appIcon: AppIconOption {
        didSet {
            UserDefaults.standard.set(appIcon.rawValue, forKey: "appIcon")
            let icon = appIcon
            Task { @MainActor in icon.apply() }
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        // v3.0 的「外观模式」旧键一次性迁移为完整主题
        if let legacy = defaults.string(forKey: "appearanceMode"), !legacy.isEmpty {
            let migrated: AppTheme = switch legacy {
            case "light": .day
            case "dark":  .darkRoom
            default:      .system
            }
            theme = migrated
            defaults.set(migrated.rawValue, forKey: "appTheme")
            defaults.removeObject(forKey: "appearanceMode")
        } else {
            theme = AppTheme(rawValue: defaults.string(forKey: "appTheme") ?? "") ?? .system
        }
        appIcon = AppIconOption(rawValue: defaults.string(forKey: "appIcon") ?? "") ?? .ivory
    }

    /// 应用主题外观与图标到整个 App（外观 nil = 跟随系统）；启动时调用
    @MainActor
    func applyAppearance() {
        NSApplication.shared.appearance = theme.nsAppearance
        appIcon.apply()
    }
}

// MARK: - 完整主题

/// 三套外观主题：跟随系统 / 白昼放映厅 / 暗房
/// 每套给齐整套语义令牌调色板；除「跟随系统」外各自锁定浅 / 深系统外观，
/// 使窗口 chrome、`colorScheme` 环境与调色板始终一致。
enum AppTheme: String, CaseIterable, Identifiable {
    case system, day, darkRoom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:   return "跟随系统"
        case .day:      return "白昼放映厅"
        case .darkRoom: return "暗房"
        }
    }

    /// 锁定的系统外观（nil = 跟随系统）
    var nsAppearance: NSAppearance? {
        switch self {
        case .system:   return nil
        case .day:      return NSAppearance(named: .aqua)
        case .darkRoom: return NSAppearance(named: .darkAqua)
        }
    }

    /// 整套语义令牌调色板
    var palette: ThemePalette {
        switch self {
        case .system:   return .system
        case .day:      return .day
        case .darkRoom: return .darkRoom
        }
    }
}

/// 一整套语义令牌调色板（窗口画布 / 卡片 / 三级文字 / 发丝线 / 凹槽 / 轨道）
struct ThemePalette {
    let bg: Color
    let panel: Color
    let ink: Color
    let ink2: Color
    let ink3: Color
    let rule: Color
    let well: Color
    let track: Color
}

extension ThemePalette {

    /// 跟随系统：深浅动态双值（即白昼 / 暗房）
    static let system = ThemePalette(
        bg:       Theme.dynamic(light: Theme.hex(0xF5F4F0), dark: Theme.hex(0x0D0E11)),
        panel:    Theme.dynamic(light: Theme.hex(0xFFFFFF), dark: Theme.hex(0x17191F)),
        ink:      Theme.dynamic(light: Theme.hex(0x1B1D23), dark: Theme.hex(0xF2F3F6)),
        ink2:     Theme.dynamic(light: Theme.hex(0x5A5F6B), dark: Theme.hex(0xA6ABB8)),
        ink3:     Theme.dynamic(light: Theme.hex(0x9AA0AC), dark: Theme.hex(0x6B7180)),
        rule:     Theme.dynamic(light: Color.black.opacity(0.09),  dark: Color.white.opacity(0.07)),
        well:     Theme.dynamic(light: Color.black.opacity(0.055), dark: Color.white.opacity(0.07)),
        track:    Theme.dynamic(light: Color.black.opacity(0.12),  dark: Color.white.opacity(0.12))
    )

    /// 白昼放映厅（暖纸调浅色）
    static let day = ThemePalette(
        bg:       Color(nsColor: Theme.hex(0xF5F4F0)),
        panel:    Color(nsColor: Theme.hex(0xFFFFFF)),
        ink:      Color(nsColor: Theme.hex(0x1B1D23)),
        ink2:     Color(nsColor: Theme.hex(0x5A5F6B)),
        ink3:     Color(nsColor: Theme.hex(0x9AA0AC)),
        rule:     Color.black.opacity(0.09),
        well:     Color.black.opacity(0.055),
        track:    Color.black.opacity(0.12)
    )

    /// 暗房（深空灰黑）
    static let darkRoom = ThemePalette(
        bg:       Color(nsColor: Theme.hex(0x0D0E11)),
        panel:    Color(nsColor: Theme.hex(0x17191F)),
        ink:      Color(nsColor: Theme.hex(0xF2F3F6)),
        ink2:     Color(nsColor: Theme.hex(0xA6ABB8)),
        ink3:     Color(nsColor: Theme.hex(0x6B7180)),
        rule:     Color.white.opacity(0.07),
        well:     Color.white.opacity(0.07),
        track:    Color.white.opacity(0.12)
    )
}
