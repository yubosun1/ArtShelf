import SwiftUI

struct MediaCardView: View {

    let item: MediaItem
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: DataStore

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            coverWell
            shelfLine
            caption
        }
        .frame(width: ArtShelfStyle.cardWidth)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) { isHovered = hovering }
        }
        .onTapGesture { open() }
        .contextMenu { contextMenuItems }
        .help(item.title)
    }

    // MARK: - 封面

    /// 所有封面共用一个固定高度的"井"，底部对齐落在书架线上。
    /// 方形专辑因此比海报矮一截，正是实体书架上的样子。
    private var coverWell: some View {
        ZStack(alignment: .topTrailing) {
            CoverImageView(
                localPath: item.localCoverPath,
                remoteURL: item.coverURL,
                aspectRatio: item.type.coverAspectRatio,
                cornerRadius: ArtShelfStyle.cardRadius
            )
            .frame(width: ArtShelfStyle.cardWidth)
            .offset(y: isHovered ? -3 : 0)

            if isHovered {
                hoverBadge
                    .offset(y: -3)
                    .transition(.opacity)
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
            .frame(width: 24, height: 24)
            .background(.regularMaterial, in: Circle())
            .padding(6)
    }

    /// 托住封面的书架横木
    private var shelfLine: some View {
        ArtShelfStyle.shelf
            .frame(height: 2)
            .clipShape(Capsule())
            .padding(.top, 4)
    }

    // MARK: - 文字

    private var caption: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title)
                .font(ArtShelfStyle.cardTitle)
                .foregroundStyle(ArtShelfStyle.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 31, alignment: .topLeading)

            HStack(spacing: 5) {
                Circle()
                    .fill(item.status.color)
                    .frame(width: 4.5, height: 4.5)

                Text(item.status.label(for: item.type))

                if let creator = item.creator, !creator.isEmpty {
                    Text("·")
                    Text(creator).lineLimit(1)
                }

                Spacer(minLength: 2)

                if let year = item.year {
                    Text(String(year)).monospacedDigit()
                }
            }
            .font(ArtShelfStyle.cardMeta)
            .foregroundStyle(ArtShelfStyle.inkSecondary)
        }
        .padding(.top, 8)
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
