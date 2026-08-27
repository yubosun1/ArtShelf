import SwiftUI

struct MediaCardView: View {

    let item: MediaItem
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: DataStore

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            coverWell
            caption
        }
        .frame(width: ArtShelfStyle.cardWidth)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) { isHovered = hovering }
        }
        .onTapGesture { open() }
        .contextMenu { contextMenuItems }
        .help(item.title)
    }

    // MARK: - 封面展示区

    private var coverWell: some View {
        ZStack(alignment: .topTrailing) {
            CoverImageView(
                localPath: item.localCoverPath,
                remoteURL: item.coverURL,
                aspectRatio: item.type.coverAspectRatio,
                cornerRadius: ArtShelfStyle.cardRadius
            )
            .frame(width: ArtShelfStyle.cardWidth)
            .cardHoverEffect(isHovered: isHovered)

            if isHovered {
                hoverBadge
                    .padding(8)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .frame(
            width: ArtShelfStyle.cardWidth,
            height: ArtShelfStyle.coverWellHeight,
            alignment: .bottom
        )
    }

    private var hoverBadge: some View {
        Image(systemName: appState.selectedSort == .custom ? "line.3.horizontal" : "arrow.up.right")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(ArtShelfStyle.ink)
            .frame(width: 28, height: 28)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }

    // MARK: - 文字信息

    private var caption: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.title)
                .font(ArtShelfStyle.cardTitle)
                .foregroundStyle(ArtShelfStyle.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)

            HStack(spacing: 6) {
                StatusBadge(status: item.status, type: item.type)

                if let creator = item.creator, !creator.isEmpty {
                    Text(creator)
                        .lineLimit(1)
                        .font(ArtShelfStyle.cardMeta)
                        .foregroundStyle(ArtShelfStyle.inkSecondary)
                }

                Spacer(minLength: 2)

                if let year = item.year {
                    Text(String(year))
                        .monospacedDigit()
                        .font(ArtShelfStyle.cardMeta)
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                }
            }
        }
    }

    // MARK: - 交互

    private func open() {
        var updated = item
        updated.lastViewedDate = Date()
        store.update(updated)
        appState.detailItem = updated
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button("详情") { appState.detailItem = item }
        Button("打开文件 / 链接") { FileService.shared.openMedia(item) }
        Divider()
        Menu("标记为") {
            ForEach(MediaStatus.allCases, id: \.self) { status in
                Button(status.label(for: item.type)) {
                    var updated = item
                    updated.status = status
                    store.update(updated)
                }
            }
        }
        Divider()
        Button("删除", role: .destructive) { store.delete(item) }
    }
}
