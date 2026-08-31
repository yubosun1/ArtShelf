import SwiftUI

/// 封面卡片：平铺封面 + 主色光晕 + 状态徽标 + 右键快捷维护
///
/// 库页网格与「此刻」精选行共用。
struct MediaCardView: View {

    let item: MediaItem
    var width: CGFloat = Theme.cardWidth

    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @State private var hovered = false
    @State private var glowColor: Color?
    @State private var confirmDelete = false

    private var height: CGFloat { width / item.type.coverAspectRatio }

    /// 徽标文案：进行中且有进度时带百分比
    private var badgeText: String {
        if item.status == .inProgress, item.progressTotal > 0 {
            return "\(item.statusLabel) \(Int(item.progress * 100))%"
        }
        return item.statusLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CoverImageView(item: item) { glowColor = $0 }
                .frame(width: width, height: height)
                .coverGlow(glowColor, scheme: scheme)
                .overlay(alignment: .topTrailing) {
                    StatusBadge(status: item.status, type: item.type, text: badgeText)
                        .padding(9)
                }
                .contentShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
                .onHover { hovered = $0 }
                .cardHoverLift(hovered, scheme: scheme)
                .onTapGesture {
                    store.markViewed(item)
                    appState.openDetail(item)
                }

            Text(item.title)
                .font(Theme.cardTitle)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .padding(.top, 10)

            Text(metaLine)
                .font(Theme.cardMeta)
                .foregroundStyle(Theme.ink3)
                .lineLimit(1)
                .padding(.top, 2)
        }
        .frame(width: width)
        .contextMenu { contextActions }
        .confirmationDialog("确定删除「\(item.title)」？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                store.delete(item)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("该藏品及其手记将被移除，封面缓存一并清理。")
        }
    }

    /// 副标题行：评分优先，其次创作者 / 年份
    private var metaLine: String {
        if item.rating > 0 {
            return "★ " + String(format: "%.1f", Double(item.rating))
        }
        return [item.creator, item.year.map(String.init)].compactMap { $0 }.joined(separator: " · ")
    }

    /// 右键菜单（product-design.md §4.2）
    @ViewBuilder
    private var contextActions: some View {
        switch item.status {
        case .planned:
            Button("开始品味") { store.startTasting(item) }
            Button("标记已看") { store.finish(item) }
        case .inProgress:
            Button("标记已看") { store.finish(item) }
        case .completed:
            Button("再看一遍") { store.replay(item) }
        }
        Button("记一笔") {
            store.markViewed(item)
            appState.openDetail(item)
        }
        Divider()
        Button("删除…", role: .destructive) { confirmDelete = true }
    }
}
