import Foundation

/// 媒体消费状态
///
/// rawValue 与 v2 JSON 线格式一致（"planned"/"inProgress"/"completed"），保证旧数据可直接解码。
enum MediaStatus: String, Codable, CaseIterable, Sendable {
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
}
