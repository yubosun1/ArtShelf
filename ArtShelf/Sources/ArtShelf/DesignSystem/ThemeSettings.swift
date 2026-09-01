import SwiftUI
import AppKit

/// 外观与主题色设置（UserDefaults 持久化，全局单例）
///
/// 视图仍读 `Theme.amber` 等静态令牌——令牌改为转发到本单例的计算属性，
/// 依赖 SwiftUI Observation 的运行时追踪，切换后全部引用点自动刷新。
/// （属性读写均发生在主线程的视图求值中；类本身不隔离，
///  以便 `Theme` 的非隔离静态上下文可以直接引用。）
@Observable
final class ThemeSettings {

    /// 全局单例（非隔离不安全标注：全部读写实际都发生在主线程的视图求值中）
    nonisolated(unsafe) static let shared = ThemeSettings()

    /// 外观模式（默认跟随系统）
    var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
            let mode = appearanceMode
            Task { @MainActor in
                NSApplication.shared.appearance = mode.nsAppearance
            }
        }
    }

    /// 主题色套件（默认琥珀）
    var accent: AccentTheme {
        didSet {
            UserDefaults.standard.set(accent.rawValue, forKey: "accentTheme")
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        appearanceMode = AppearanceMode(rawValue: defaults.string(forKey: "appearanceMode") ?? "") ?? .system
        accent = AccentTheme(rawValue: defaults.string(forKey: "accentTheme") ?? "") ?? .amber
    }

    /// 应用外观到整个 App（nil = 跟随系统）；启动时调用
    @MainActor
    func applyAppearance() {
        NSApplication.shared.appearance = appearanceMode.nsAppearance
    }
}

// MARK: - 外观模式

/// 跟随系统 / 白昼放映厅（浅） / 暗房（深）
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light:  return "白昼放映厅"
        case .dark:   return "暗房"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light:  return NSAppearance(named: .aqua)
        case .dark:   return NSAppearance(named: .darkAqua)
        }
    }
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
