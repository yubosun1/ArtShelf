import SwiftUI

/// 全局搜索结果浮层：跨三类全字段即时检索，点击 / 回车直达详情
struct GlobalSearchView: View {

    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    private var results: [MediaItem] {
        Array(Self.filter(store.items, query: appState.searchText).prefix(8))
    }

    var body: some View {
        VStack(spacing: 0) {
            if results.isEmpty {
                Text("没有匹配「\(appState.searchText)」的藏品")
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink3)
                    .padding(.vertical, 22)
            } else {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Rectangle().fill(Theme.rule).frame(height: 1).padding(.leading, 56)
                    }
                    row(for: item)
                }
            }
        }
        .frame(width: 420)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.rule, lineWidth: 1)
        )
        // 投影强度并入 Theme 标量体系（随深浅外观变化）
        .shadow(color: .black.opacity(Theme.shadowAlpha(colorScheme)), radius: 24, y: 10)
    }

    private func row(for item: MediaItem) -> some View {
        Button {
            store.markViewed(item)
            appState.openDetail(item)
        } label: {
            HStack(spacing: 12) {
                CoverImageView(item: item, cornerRadius: 4)
                    .frame(width: 28, height: 28 / item.type.coverAspectRatio)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(metaLine(for: item))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.ink3)
                        .lineLimit(1)
                }
                Spacer()
                StatusBadge(status: item.status, type: item.type)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func metaLine(for item: MediaItem) -> String {
        [item.type.rawValue, item.creator, item.year.map(String.init)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    // MARK: - 检索逻辑（顶栏回车直达复用）

    /// 跨三类全字段：标题 / 创作者 / 类型 / 标签 / 简介 / 手记正文
    static func filter(_ items: [MediaItem], query: String) -> [MediaItem] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return items.filter { item in
            if item.title.lowercased().contains(q) { return true }
            if item.creator?.lowercased().contains(q) == true { return true }
            if item.genre?.lowercased().contains(q) == true { return true }
            if item.albumName?.lowercased().contains(q) == true { return true }
            if item.tags.contains(where: { $0.lowercased().contains(q) }) { return true }
            if item.synopsis?.lowercased().contains(q) == true { return true }
            if item.notes.contains(where: { $0.text.lowercased().contains(q) }) { return true }
            return false
        }
    }
}
