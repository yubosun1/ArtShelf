import SwiftUI

/// 媒体消费状态
enum MediaStatus: String, Codable, CaseIterable {
    case planned       // 待看 / 待听 / 待读
    case inProgress    // 在看 / 在听 / 在读
    case completed     // 已看 / 已听 / 已读

    func label(for type: MediaType) -> String {
        switch self {
        case .planned:    return type.plannedLabel
        case .inProgress: return type.inProgressLabel
        case .completed:  return type.completedLabel
        }
    }

    /// 状态点的颜色——取暖色域内的三个色相，与纸质底调协调，
    /// 避免系统蓝/绿在米色背景上显得刺眼。
    var color: Color {
        switch self {
        case .planned:    return Color(red: 0.58, green: 0.55, blue: 0.49)  // 石灰
        case .inProgress: return Color(red: 0.85, green: 0.55, blue: 0.18)  // 琥珀
        case .completed:  return Color(red: 0.40, green: 0.56, blue: 0.38)  // 橄榄
        }
    }

    var iconName: String {
        switch self {
        case .planned:    return "circle.dashed"
        case .inProgress: return "circle.lefthalf.filled"
        case .completed:  return "circle.fill"
        }
    }
}
