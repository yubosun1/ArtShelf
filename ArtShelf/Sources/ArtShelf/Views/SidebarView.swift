import SwiftUI

struct SidebarView: View {

    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(title: "资料库")
                        .padding(.horizontal, 14)
                        .padding(.top, 6)
                        .padding(.bottom, 7)

                    sidebarRow(
                        title: "全部收藏",
                        count: store.items.count,
                        isSelected: appState.selectedCategory == nil && appState.selectedTag == nil
                    ) {
                        selectCategory(nil)
                    }

                    ForEach(MediaType.allCases) { type in
                        sidebarRow(
                            title: type.rawValue,
                            count: store.items.filter { $0.type == type }.count,
                            isSelected: appState.selectedCategory == type && appState.selectedTag == nil
                        ) {
                            selectCategory(type)
                        }
                    }

                    if !store.allTags.isEmpty {
                        SectionLabel(title: "标签")
                            .padding(.horizontal, 14)
                            .padding(.top, 20)
                            .padding(.bottom, 7)

                        ForEach(store.allTags, id: \.self) { tag in
                            DraggableTagRow(
                                title: tag,
                                count: store.items.filter { $0.tags.contains(tag) }.count,
                                isSelected: appState.selectedTag == tag,
                                onMove: { dragged in
                                    withAnimation(.easeOut(duration: 0.18)) {
                                        store.moveTag(dragged, before: tag)
                                    }
                                }
                            ) {
                                withAnimation(.easeOut(duration: 0.16)) {
                                    appState.selectedCategory = nil
                                    appState.selectedTag = appState.selectedTag == tag ? nil : tag
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }

            PaperRule()

            // 底部状态栏：书脊上的落款，宋体一级墨色
            HStack(spacing: 7) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 10.5, weight: .medium))
                Text("ArtShelf")
                    .font(ArtShelfStyle.serifTitle(11, weight: .medium))
                Spacer()
                Text("\(store.items.count)")
                    .font(ArtShelfStyle.serifTitle(11, weight: .medium).monospacedDigit())
            }
            .foregroundStyle(ArtShelfStyle.inkTertiary)
            .padding(.horizontal, 15)
            .padding(.vertical, 9)
        }
        .background(ArtShelfStyle.surface)
    }

    private func selectCategory(_ category: MediaType?) {
        withAnimation(.easeOut(duration: 0.16)) {
            appState.selectedCategory = category
            appState.selectedTag = nil
        }
    }

    private func sidebarRow(
        title: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        SidebarRow(
            title: title,
            count: count,
            isSelected: isSelected,
            action: action
        )
    }
}

/// 目录索引里的一行：纯文字宋体行题（不配图标），选中态 = accentWash 浅底（圆角 4）
/// + 行首内侧 2pt 朱砂竖条，标题与计数一并转成朱砂。
private struct SidebarRow: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Text(title)
                    .font(ArtShelfStyle.serifTitle(13, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)

                Spacer(minLength: 6)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(isSelected ? ArtShelfStyle.accent : ArtShelfStyle.inkTertiary)
                }
            }
            .foregroundStyle(isSelected ? ArtShelfStyle.accent : ArtShelfStyle.ink)
            .padding(.horizontal, 9)
            .frame(height: 29)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isSelected ? ArtShelfStyle.accentWash
                                     : (isHovered ? ArtShelfStyle.hoverFill : .clear))
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    // 行首内侧的朱砂竖条——目录当前位的标记
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(ArtShelfStyle.accent)
                        .frame(width: 2, height: 14)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) { isHovered = hovering }
        }
    }
}

/// 可拖拽排序的标签行——不使用 Button（Button 会拦截鼠标按下，导致 draggable 无法启动），
/// 改用 onTapGesture 处理点击。放置逻辑在行内通过 onDrop 完成。视觉与分类行一致。
private struct DraggableTagRow: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let onMove: (String) -> Void
    let action: () -> Void

    @State private var isHovered = false
    @State private var isDropTarget = false

    var body: some View {
        HStack(spacing: 9) {
            Text(title)
                .font(ArtShelfStyle.serifTitle(13, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)

            Spacer(minLength: 6)

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(isSelected ? ArtShelfStyle.accent : ArtShelfStyle.inkTertiary)
            }
        }
        .foregroundStyle(isSelected ? ArtShelfStyle.accent : ArtShelfStyle.ink)
        .padding(.horizontal, 9)
        .frame(height: 29)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isSelected ? ArtShelfStyle.accentWash
                                 : (isDropTarget ? ArtShelfStyle.accentWash
                                                : (isHovered ? ArtShelfStyle.hoverFill : .clear)))
        )
        .overlay(alignment: .leading) {
            if isSelected {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(ArtShelfStyle.accent)
                    .frame(width: 2, height: 14)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) { isHovered = hovering }
        }
        .onTapGesture(perform: action)
        .onDrag {
            NSItemProvider(object: title as NSString)
        } preview: {
            Text(title)
                .font(ArtShelfStyle.serifTitle(13, weight: .medium))
                .foregroundStyle(ArtShelfStyle.ink)
                .padding(.horizontal, 9)
                .frame(height: 29)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(ArtShelfStyle.well)
                )
        }
        .onDrop(of: [.plainText], isTargeted: $isDropTarget) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                if let string = object as? String {
                    DispatchQueue.main.async {
                        onMove(string)
                    }
                }
            }
            return true
        }
    }
}
