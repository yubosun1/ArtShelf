import Foundation

/// 一条策展手记（笔记条目）
struct NoteEntry: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var text: String

    init(text: String, createdAt: Date = Date()) {
        self.createdAt = createdAt
        self.text = text
    }
}
