import SwiftUI

/// 「此刻」Hero：最近品味中的藏品全景 —— 大封面 + 环境色渲染 + 进度 + 快捷动作
struct NowHeroView: View {

    let item: MediaItem
    /// 其余进行中藏品（队列卡片）
    let queue: [MediaItem]

    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @State private var glowColor: Color?

    var body: some View {
        VStack(spacing: 0) {
            heroStage
            if !queue.isEmpty {
                queueRow
                    .padding(.top, 34)
            }
        }
        .padding(.horizontal, Theme.contentPadding)
        .padding(.top, 44)
        .padding(.bottom, 40)
        .background(ambient)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.rule).frame(height: 1)
        }
    }

    // MARK: - 环境色渲染（封面主色虚化铺开）

    private var ambient: some View {
        ZStack {
            // 封面自身放大模糊打底（无字版，避免文字虚化成鬼影）
            CoverImageView(item: item, cornerRadius: 0, showsPlaceholderText: false)
                .blur(radius: 90)
                .opacity(0.55)
            // 主色径向渲染
            if let glowColor {
                RadialGradient(
                    colors: [glowColor.opacity(0.5), .clear],
                    center: .init(x: 0.2, y: 0.3),
                    startRadius: 40, endRadius: 520
                )
            }
        }
        .opacity(Theme.ambientOpacity(scheme))
        .clipped()
    }

    // MARK: - 主舞台

    private var heroStage: some View {
        HStack(alignment: .bottom, spacing: 44) {
            CoverImageView(item: item, cornerRadius: 10) { glowColor = $0 }
                .frame(width: 236, height: 354)
                .coverGlow(glowColor, scheme: scheme)

            VStack(alignment: .leading, spacing: 0) {
                kicker
                Text(item.title)
                    .font(Theme.heroTitle)
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 14)
                Text(metaLine)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink2)
                    .padding(.top, 8)
                if !item.tags.isEmpty { tagRow.padding(.top, 18) }
                if let note = item.latestNote { quote(note.text).padding(.top, 18) }
                if item.progressTotal > 0 { progressRow.padding(.top, 24) }
                actionRow.padding(.top, 26)
            }
            .padding(.bottom, 6)
        }
    }

    private var kicker: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Theme.amberBtn)
                .frame(width: 8, height: 8)
                .shadow(color: Theme.amberBtn, radius: 6)
            Text("此刻正在品味 · CONTINUE")
                .font(Theme.kicker)
                .tracking(3)
                .foregroundStyle(Theme.amber)
        }
    }

    private var metaLine: String {
        var parts = [item.creator, item.year.map(String.init), item.genre].compactMap { $0 }
        if item.replayCount > 0 {
            parts.append("第 \(item.replayCount + 1) 次重温")
        }
        return parts.joined(separator: "  ·  ")
    }

    private var tagRow: some View {
        HStack(spacing: 8) {
            ForEach(item.tags.prefix(3), id: \.self) { tag in
                Text("# \(tag)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.ink2)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 4)
                    .background(Theme.well)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Theme.rule, lineWidth: 1))
            }
        }
    }

    private func quote(_ text: String) -> some View {
        Text("「\(text)」")
            .font(.system(size: 14.5))
            .foregroundStyle(Theme.ink2)
            .lineSpacing(7)
            .lineLimit(3)
            .frame(maxWidth: 560, alignment: .leading)
    }

    private var progressRow: some View {
        HStack(spacing: 14) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.amberBtn, Theme.amberHi],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * item.progress)
                        .shadow(color: Theme.amberBtn.opacity(0.5), radius: 7)
                }
            }
            .frame(width: 380, height: 5)
            Text("\(item.progressText) · \(Int(item.progress * 100))%")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.amber)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                FileService.shared.openMedia(
                    localFilePath: item.localFilePath,
                    webURL: item.webURL,
                    appleMusicURL: item.appleMusicURL,
                    type: item.type
                )
            } label: {
                Label(item.type.continueLabel, systemImage: "play.fill")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(Theme.amberOn)
                    .padding(.horizontal, 22)
                    .frame(height: 38)
                    .background(Theme.amberBtn)
                    .clipShape(Capsule())
                    .shadow(color: Theme.amberBtn.opacity(0.32), radius: 11, y: 8)
            }
            .buttonStyle(.plain)

            ghostButton("记一笔", systemImage: "square.and.pencil") {
                appState.openDetail(item)
            }
            ghostButton("全部笔记", systemImage: "list.bullet") {
                appState.openDetail(item)
            }

            RatingStars(rating: item.rating, size: 13)
                .padding(.leading, 4)
        }
    }

    private func ghostButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 18)
                .frame(height: 38)
                .background(Theme.well)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Theme.rule, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 进行中队列

    private var queueRow: some View {
        HStack(spacing: 12) {
            ForEach(queue.prefix(4)) { item in
                queueCard(item)
            }
        }
    }

    private func queueCard(_ entry: MediaItem) -> some View {
        Button {
            store.markViewed(entry)
            appState.openDetail(entry)
        } label: {
            HStack(spacing: 12) {
                CoverImageView(item: entry, cornerRadius: 5)
                    .frame(width: 40, height: 40 / entry.type.coverAspectRatio)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(queueMeta(entry))
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.ink3)
                        .lineLimit(1)
                    if entry.progressTotal > 0 {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.track)
                                Capsule().fill(Theme.amberBtn)
                                    .frame(width: geo.size.width * entry.progress)
                            }
                        }
                        .frame(height: 3)
                        .padding(.top, 5)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                if entry.progressTotal > 0 {
                    Text("\(Int(entry.progress * 100))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.amber)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(Theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.rule, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func queueMeta(_ entry: MediaItem) -> String {
        var parts = [entry.type.rawValue]
        if let creator = entry.creator { parts.append(creator) }
        if entry.progressTotal > 0 { parts.append(entry.progressText) }
        return parts.joined(separator: " · ")
    }
}
