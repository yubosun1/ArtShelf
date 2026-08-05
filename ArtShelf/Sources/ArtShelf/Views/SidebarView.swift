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
                        icon: "square.stack",
                        title: "全部收藏",
                        count: store.items.count,
                        isSelected: appState.selectedCategory == nil && appState.selectedTag == nil
                    ) {
                        selectCategory(nil)
                    }

                    ForEach(MediaType.allCases) { type in
                        sidebarRow(
                            icon: type.systemImage,
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

            HStack(spacing: 7) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 10.5, weight: .medium))
                Text("ArtShelf")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text("\(store.items.count)")
                    .font(.system(size: 11).monospacedDigit())
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
        icon: String,
        title: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        SidebarRow(
            icon: icon,
            title: title,
            count: count,
            isSelected: isSelected,
            action: action
        )
    }
}

private struct SidebarRow: View {
    let icon: String
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)

                Spacer(minLength: 6)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(isSelected ? ArtShelfStyle.accent.opacity(0.7) : ArtShelfStyle.inkTertiary)
                }
            }
            .foregroundStyle(isSelected ? ArtShelfStyle.accent : ArtShelfStyle.ink)
            .padding(.horizontal, 9)
            .frame(height: 27)
            .background(
                RoundedRectangle(cornerRadius: ArtShelfStyle.controlRadius, style: .continuous)
                    .fill(isSelected ? ArtShelfStyle.accentWash
                                     : (isHovered ? ArtShelfStyle.hoverFill : .clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) { isHovered = hovering }
        }
    }
}

/// 可拖拽排序的标签行——不使用 Button（Button 会拦截鼠标按下，导致 draggable 无法启动），
/// 改用 onTapGesture 处理点击。放置逻辑在行内通过 onDrop 完成。
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
                .font(.system(size: 12, weight: .medium))
                .frame(width: 16)

            Text(title)
                .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                .lineLimit(1)

            Spacer(minLength: 6)

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 10.5).monospacedDigit())
                    .foregroundStyle(isSelected ? ArtShelfStyle.accent.opacity(0.7) : ArtShelfStyle.inkTertiary)
            }
        }
        .foregroundStyle(isSelected ? ArtShelfStyle.accent : ArtShelfStyle.ink)
        .padding(.horizontal, 9)
        .frame(height: 27)
        .background(
            RoundedRectangle(cornerRadius: ArtShelfStyle.controlRadius, style: .continuous)
                .fill(isSelected ? ArtShelfStyle.accentWash
                                 : (isDropTarget ? ArtShelfStyle.accentWash
                                                : (isHovered ? ArtShelfStyle.hoverFill : .clear)))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) { isHovered = hovering }
        }
        .onTapGesture(perform: action)
        .onDrag {
            NSItemProvider(object: title as NSString)
        } preview: {
            Label(title, systemImage: "number")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(ArtShelfStyle.ink)
                .padding(.horizontal, 9)
                .frame(height: 27)
                .background(
                    RoundedRectangle(cornerRadius: ArtShelfStyle.controlRadius, style: .continuous)
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
