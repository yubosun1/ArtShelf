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

    /// 主题色套件（默认琥珀；与完整主题正交）
    var accent: AccentTheme {
        didSet {
            UserDefaults.standard.set(accent.rawValue, forKey: "accentTheme")
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
        accent = AccentTheme(rawValue: defaults.string(forKey: "accentTheme") ?? "") ?? .amber
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

/// 五套完整主题：跟随系统 / 白昼放映厅 / 暗房 / 午夜蓝场 / 羊皮纸
/// 每套给齐整套语义令牌调色板；除「跟随系统」外各自锁定浅 / 深系统外观，
/// 使窗口 chrome、`colorScheme` 环境与调色板始终一致。
enum AppTheme: String, CaseIterable, Identifiable {
    case system, day, darkRoom, midnight, parchment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:    return "跟随系统"
        case .day:       return "白昼放映厅"
        case .darkRoom:  return "暗房"
        case .midnight:  return "午夜蓝场"
        case .parchment: return "羊皮纸"
        }
    }

    /// 锁定的系统外观（nil = 跟随系统）
    var nsAppearance: NSAppearance? {
        switch self {
        case .system:              return nil
        case .day, .parchment:     return NSAppearance(named: .aqua)
        case .darkRoom, .midnight: return NSAppearance(named: .darkAqua)
        }
    }

    /// 整套语义令牌调色板
    var palette: ThemePalette {
        switch self {
        case .system:    return .system
        case .day:       return .day
        case .darkRoom:  return .darkRoom
        case .midnight:  return .midnight
        case .parchment: return .parchment
        }
    }
}

/// 一整套语义令牌调色板（窗口画布 / 标题栏 / 卡片 / 三级文字 / 发丝线 / 凹槽 / 轨道）
struct ThemePalette {
    let bg: Color
    let titlebar: Color
    let panel: Color
    let ink: Color
    let ink2: Color
    let ink3: Color
    let rule: Color
    let well: Color
    let track: Color
}

extension ThemePalette {

    /// 跟随系统：深浅动态双值（即 v3.0 的白昼 / 暗房）
    static let system = ThemePalette(
        bg:       Theme.dynamic(light: Theme.hex(0xF5F4F0), dark: Theme.hex(0x0D0E11)),
        titlebar: Theme.dynamic(light: Theme.hex(0xECEAE3), dark: Theme.hex(0x101116)),
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
        titlebar: Color(nsColor: Theme.hex(0xECEAE3)),
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
        titlebar: Color(nsColor: Theme.hex(0x101116)),
        panel:    Color(nsColor: Theme.hex(0x17191F)),
        ink:      Color(nsColor: Theme.hex(0xF2F3F6)),
        ink2:     Color(nsColor: Theme.hex(0xA6ABB8)),
        ink3:     Color(nsColor: Theme.hex(0x6B7180)),
        rule:     Color.white.opacity(0.07),
        well:     Color.white.opacity(0.07),
        track:    Color.white.opacity(0.12)
    )

    /// 午夜蓝场（藏青底深色系）
    static let midnight = ThemePalette(
        bg:       Color(nsColor: Theme.hex(0x0B1220)),
        titlebar: Color(nsColor: Theme.hex(0x0E1526)),
        panel:    Color(nsColor: Theme.hex(0x141C30)),
        ink:      Color(nsColor: Theme.hex(0xE8EDF7)),
        ink2:     Color(nsColor: Theme.hex(0x93A0BC)),
        ink3:     Color(nsColor: Theme.hex(0x5E6B87)),
        rule:     Color.white.opacity(0.07),
        well:     Color.white.opacity(0.07),
        track:    Color.white.opacity(0.12)
    )

    /// 羊皮纸（暖复古浅色）
    static let parchment = ThemePalette(
        bg:       Color(nsColor: Theme.hex(0xF0E8D8)),
        titlebar: Color(nsColor: Theme.hex(0xE7DECC)),
        panel:    Color(nsColor: Theme.hex(0xFAF5E9)),
        ink:      Color(nsColor: Theme.hex(0x2E2620)),
        ink2:     Color(nsColor: Theme.hex(0x6B5D4F)),
        ink3:     Color(nsColor: Theme.hex(0x9C8D7B)),
        rule:     Color.black.opacity(0.10),
        well:     Color.black.opacity(0.06),
        track:    Color.black.opacity(0.12)
    )
}

// MARK: - 主题色套件

/// 四套主题色：琥珀（默认）/ 靛蓝 / 青玉 / 胭脂
/// 每套给齐：强调文字色（深浅）、主按钮底色与其上文字色（深浅）、渐亮端；
/// 「进行中」徽标由此派生（bg = 强调色 14%/26% 透明，字 = 浅用强调色 / 深用渐亮端）。
enum AccentTheme: String, CaseIterable, Identifiable {
    case amber, indigo, teal, rouge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .amber:  return "琥珀"
        case .indigo: return "靛蓝"
        case .teal:   return "青玉"
        case .rouge:  return "胭脂"
        }
    }

    // 色值：（浅色强调, 深色强调, 按钮底, 按钮上文字·浅, 按钮上文字·深, 渐亮端）
    private var values: (NSColor, NSColor, NSColor, NSColor, NSColor, NSColor) {
        switch self {
        case .amber:
            return (Theme.hex(0xC07A14), Theme.hex(0xE8A33D), Theme.hex(0xE8A33D),
                    Theme.hex(0x2A1B06), Theme.hex(0x1A1208), Theme.hex(0xF5C063))
        case .indigo:
            return (Theme.hex(0x3B5FD9), Theme.hex(0x7A9AFF), Theme.hex(0x5B82F6),
                    Theme.hex(0xF5F8FF), Theme.hex(0xF5F8FF), Theme.hex(0xA9C0FF))
        case .teal:
            return (Theme.hex(0x17726C), Theme.hex(0x4EC9C0), Theme.hex(0x2AA7A0),
                    Theme.hex(0x042926), Theme.hex(0x042926), Theme.hex(0x8FE3DC))
        case .rouge:
            return (Theme.hex(0xB02F6C), Theme.hex(0xF06EA8), Theme.hex(0xE85B9B),
                    Theme.hex(0x3A0A22), Theme.hex(0x3A0A22), Theme.hex(0xF8A8CC))
        }
    }

    /// 强调色（文字 / 进度 / 点睛，随深浅外观）
    var accent: Color {
        let v = values
        return Theme.dynamic(light: v.0, dark: v.1)
    }

    /// 主按钮底色（深浅一致）
    var button: Color { Color(nsColor: values.2) }

    /// 主按钮上的文字色
    var buttonOn: Color {
        let v = values
        return Theme.dynamic(light: v.3, dark: v.4)
    }

    /// 渐亮端（进度条渐变 / 深色下「进行中」文字）
    var highlight: Color { Color(nsColor: values.5) }

    /// 「进行中」徽标底色
    var doingBg: Color {
        let v = values
        return Theme.dynamic(
            light: v.0.withAlphaComponent(0.14),
            dark: v.1.withAlphaComponent(0.26)
        )
    }

    /// 「进行中」徽标文字色
    var doingTx: Color {
        let v = values
        return Theme.dynamic(light: v.0, dark: v.5)
    }
}
