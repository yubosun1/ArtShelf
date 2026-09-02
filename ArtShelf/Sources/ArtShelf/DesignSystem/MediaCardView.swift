import SwiftUI

/// 封面卡片：平铺封面 + 主色光晕 + 状态徽标 + 右键快捷维护（含就地手记浮层）
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
    @State private var notePopover = false
    @State private var noteDraft = ""
    @FocusState private var noteFocused: Bool

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
                .overlay {
                    // 概念稿 .card .cov::after: 底部微暗渐变，让封面更具厚重感
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.35)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    StatusBadge(status: item.status, type: item.type, text: badgeText)
                        .padding(9)
                }
                .coverGlow(glowColor, scheme: scheme)
                .contentShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
                .cardHoverLift(hovered)
                .zIndex(hovered ? 2 : 0)
                .onHover { hovered = $0 }

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
        .contentShape(Rectangle())
        .onTapGesture {
            store.markViewed(item)
            appState.openDetail(item)
        }
        .contextMenu { contextActions }
        .popover(isPresented: $notePopover, arrowEdge: .top) {
            quickNoteEditor
        }
        .confirmationDialog("确定删除「\(item.title)」？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                // 磁盘封面由 store.delete 清理，内存缓存（含主色）一并逐出
                CoverImageLoader.evict(id: item.id)
                store.delete(item)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("该藏品及其手记将被移除，封面缓存一并清理。")
        }
    }

    /// 副标题行：评分优先，进行中给进度，其次状态，兜底创作者 / 年份
    private var metaLine: String {
        if item.rating > 0 {
            return "★ " + String(format: "%.1f", Double(item.rating))
        }
        if item.status == .inProgress, item.progressTotal > 0 {
            return item.progressText
        }
        let byline = [item.creator, item.year.map(String.init)].compactMap { $0 }.joined(separator: " · ")
        return byline.isEmpty ? item.statusLabel : byline
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
            // 等右键菜单收起后再弹浮层，避免 popover 在菜单收尾动画期间无法呈现；
            // 菜单操作间隙藏品可能已被删除（如其他入口），弹出前确认仍在库
            DispatchQueue.main.async {
                guard store.item(for: item.id) != nil else { return }
                notePopover = true
            }
        }
        Divider()
        Button("删除…", role: .destructive) { confirmDelete = true }
    }

    /// 就地「记一笔」浮层：多行输入 + 「记下」按钮，提交即入库、不跳详情
    ///（风格呼应详情页手记编辑器：well 底、rule 边、圆角 10 输入框 + panel 底面板）
    private var quickNoteEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                if noteDraft.isEmpty {
                    Text("记下此刻的感受…")
                        .font(Theme.body)
                        .foregroundStyle(Theme.ink3)
                        .padding(.top, 9)
                        .padding(.leading, 11)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $noteDraft)
                    .font(Theme.body)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                    .focused($noteFocused)
                    .padding(6)
                    .frame(width: 240, height: 66)
                    .background(Theme.well)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Theme.rule, lineWidth: 1)
                    )
            }
            HStack {
                Spacer()
                Button("记下") { commitQuickNote() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                    .opacity(noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 1)
            }
        }
        .padding(16)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: Theme.panelCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.panelCorner, style: .continuous)
                .strokeBorder(Theme.rule, lineWidth: 1)
        )
        .onAppear {
            noteDraft = ""
            // 浮层出现后聚焦输入框，省一次点击
            DispatchQueue.main.async { noteFocused = true }
        }
    }

    /// 提交就地手记：入库后收起浮层
    private func commitQuickNote() {
        let text = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.addNote(item, text: text)
        noteDraft = ""
        notePopover = false
    }
}
