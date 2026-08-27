import SwiftUI

struct SidebarView: View {

    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel(title: "资料库")
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                        .padding(.bottom, 6)

                    sidebarRow(
                        title: "全部收藏",
                        icon: "square.grid.2x2.fill",
                        count: store.items.count,
                        isSelected: appState.selectedCategory == nil && appState.selectedTag == nil
                    ) {
                        selectCategory(nil)
                    }

                    ForEach(MediaType.allCases) { type in
                        sidebarRow(
                            title: type.rawValue,
                            icon: categoryIcon(for: type),
                            count: store.items.filter { $0.type == type }.count,
                            isSelected: appState.selectedCategory == type && appState.selectedTag == nil
                        ) {
                            selectCategory(type)
                        }
                    }

                    if !store.allTags.isEmpty {
                        SectionLabel(title: "标签")
                            .padding(.horizontal, 14)
                            .padding(.top, 22)
                            .padding(.bottom, 6)

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
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }

            PaperRule()

            // 底部精细状态栏
            HStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(ArtShelfStyle.accent)
                Text("ArtShelf")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(ArtShelfStyle.inkSecondary)
                Spacer()
                Text("\(store.items.count) 项")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(ArtShelfStyle.inkTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
        .background(ArtShelfStyle.sidebarBackground)
    }

    private func categoryIcon(for type: MediaType) -> String {
        switch type {
        case .movie: return "film.stack.fill"
        case .music: return "opticaldisc.fill"
        case .book:  return "books.vertical.fill"
        }
    }

    private func selectCategory(_ category: MediaType?) {
        withAnimation(.easeOut(duration: 0.16)) {
            appState.selectedCategory = category
            appState.selectedTag = nil
        }
    }

    private func sidebarRow(
        title: String,
        icon: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        SidebarRow(
            title: title,
            icon: icon,
            count: count,
            isSelected: isSelected,
            action: action
        )
    }
}

/// 现代 macOS 侧栏行：精致图标 + 文字 + 悬浮/选中反馈 + 药丸数字角标
private struct SidebarRow: View {
    let title: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(isSelected ? ArtShelfStyle.accent : ArtShelfStyle.inkSecondary)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)

                Spacer(minLength: 6)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(isSelected ? ArtShelfStyle.accent : ArtShelfStyle.inkTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? ArtShelfStyle.accent.opacity(0.12) : ArtShelfStyle.hoverFill)
                        )
                }
            }
            .foregroundStyle(isSelected ? ArtShelfStyle.accent : ArtShelfStyle.ink)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? ArtShelfStyle.accentWash : (isHovered ? ArtShelfStyle.hoverFill : .clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovered = hovering }
        }
    }
}

/// 现代可拖拽排序标签行
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
            Image(systemName: "number")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isSelected ? ArtShelfStyle.accent : ArtShelfStyle.inkTertiary)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)

            Spacer(minLength: 6)

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(isSelected ? ArtShelfStyle.accent : ArtShelfStyle.inkTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(
                        Capsule()
                            .fill(isSelected ? ArtShelfStyle.accent.opacity(0.12) : ArtShelfStyle.hoverFill)
                    )
            }
        }
        .foregroundStyle(isSelected ? ArtShelfStyle.accent : ArtShelfStyle.ink)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? ArtShelfStyle.accentWash
                                 : (isDropTarget ? ArtShelfStyle.accentWash
                                                : (isHovered ? ArtShelfStyle.hoverFill : .clear)))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovered = hovering }
        }
        .onTapGesture(perform: action)
        .onDrag {
            NSItemProvider(object: title as NSString)
        } preview: {
            HStack(spacing: 6) {
                Image(systemName: "number")
                Text(title)
            }
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(ArtShelfStyle.ink)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(ArtShelfStyle.surface)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
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
