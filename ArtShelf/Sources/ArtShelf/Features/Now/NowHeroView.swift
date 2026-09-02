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
            // 封面自身超大虚化铺底
            CoverImageView(item: item, cornerRadius: 0, showsPlaceholderText: false)
                .scaledToFill()
                .blur(radius: 100)
                .opacity(0.40)

            // 三层戏剧化径向渐变（完全对齐 Demo .hero .ambient：左中主色扩散、右下次色烘托、右上微光点缀）
            if let glowColor {
                let primary = glowColor
                let secondary = derivedSecondaryColor(from: glowColor)

                // 1. 左侧大面积主色光团（22% 30%）
                RadialGradient(
                    colors: [primary.opacity(0.60), .clear],
                    center: .init(x: 0.22, y: 0.30),
                    startRadius: 30, endRadius: 600
                )
                // 2. 右下方深层冷暖对比次色（70% 110%）
                RadialGradient(
                    colors: [secondary.opacity(0.48), .clear],
                    center: .init(x: 0.70, y: 1.05),
                    startRadius: 40, endRadius: 520
                )
                // 3. 右上方琥珀暖调微光（85% 10%）—— Demo signature: rgba(232,163,61,.16)
                RadialGradient(
                    colors: [Theme.amberBtn.opacity(0.22), .clear],
                    center: .init(x: 0.85, y: 0.10),
                    startRadius: 20, endRadius: 380
                )
            }
        }
        .opacity(Theme.ambientOpacity(scheme))
        // 底部向透明淡出：环境色在到达分隔线之前散尽，不硬切、不渗进下方分区
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white, location: 0.62),
                    .init(color: .clear, location: 0.94)
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .clipped()
    }

    /// 根据主色衍生互补/调和的暗调次级色，使暗房光影具有丰富的空间景深感
    private func derivedSecondaryColor(from color: Color) -> Color {
        let ns = NSColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let shiftedHue = fmod(h + 0.38, 1.0)
        let secNS = NSColor(hue: shiftedHue, saturation: min(1.0, s * 0.9), brightness: max(0.25, b * 0.5), alpha: a)
        return Color(nsColor: secNS)
    }

    // MARK: - 主舞台

    private var heroStage: some View {
        HStack(alignment: .bottom, spacing: 44) {
            CoverImageView(item: item, cornerRadius: 10) { glowColor = $0 }
                .frame(width: Theme.heroCoverSize.width, height: Theme.heroCoverSize.height)
                .coverGlow(glowColor, scheme: scheme)
                // 与藏品卡一致：点击封面进详情（并刷新最近浏览）
                .onTapGesture {
                    store.markViewed(item)
                    appState.openDetail(item)
                }
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }

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
                if !item.tags.isEmpty { tagRow.padding(.top, 16) }
                if let note = item.latestNote { quote(note.text).padding(.top, 18) }
                progressRow.padding(.top, 22)
                actionRow.padding(.top, 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            if item.progressTotal > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.track)
                        Capsule()
                            .fill(LinearGradient(colors: [Theme.amberBtn, Theme.amberHi],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, min(geo.size.width, geo.size.width * item.progress)))
                            .shadow(color: Theme.amberBtn.opacity(0.5), radius: 7)
                    }
                }
                .frame(width: 380, height: 5)
                Text("\(item.progressText) · \(Int(item.progress * 100))%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.amber)
            } else {
                // 未登记总量时，以微光胶囊展示品味状态，避免留出突兀空白断层
                HStack(spacing: 6) {
                    Circle().fill(Theme.amberBtn).frame(width: 6, height: 6)
                    Text("持续品味中")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.ink2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 3.5)
                .background(Theme.well)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Theme.rule, lineWidth: 1))
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                // 唤起成功才刷新品味时间，驱动 Hero 与队列排序（§6）
                guard FileService.shared.openMedia(
                    localFilePath: item.localFilePath,
                    webURL: item.webURL,
                    appleMusicURL: item.appleMusicURL,
                    type: item.type
                ) else { return }
                store.markTasted(item)
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
                appState.openDetail(item, intent: .writeNote)
            }
            ghostButton("全部笔记", systemImage: "list.bullet") {
                appState.openDetail(item)
            }

            RatingStars(rating: item.rating, size: 13)
                .padding(.leading, 4)
            if item.rating > 0 {
                Text(String(format: "%.1f", Double(item.rating)))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink3)
                    .padding(.leading, 8)
            }
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
        // 对齐 Demo 四列等宽网格：≤4 张时卡片与空列均分宽度；多于 4 张时启用水平平滑滚动（固定 280 宽）
        Group {
            if queue.count <= 4 {
                HStack(spacing: 12) {
                    ForEach(queue) { entry in
                        QueueCard(entry: entry)
                    }
                    if queue.count < 4 {
                        ForEach(0 ..< (4 - queue.count), id: \.self) { _ in
                            Spacer().frame(maxWidth: .infinity)
                        }
                    }
                }
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(queue) { entry in
                            QueueCard(entry: entry, width: 280)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    /// 进行中队列卡片：迷你封面 + 标题 / 元信息 / 进度，点击进入详情并刷新最近浏览
    private struct QueueCard: View {

        let entry: MediaItem
        /// 固定宽（横滚队列用 280）；nil 时按四列网格弹性等宽
        var width: CGFloat? = nil

        @Environment(AppState.self) private var appState
        @Environment(LibraryStore.self) private var store
        @Environment(\.colorScheme) private var scheme
        @State private var hovered = false

        var body: some View {
            Button {
                store.markViewed(entry)
                appState.openDetail(entry)
            } label: {
                let coverSize = Theme.queueCoverSize(for: entry.type)
                HStack(spacing: 12) {
                    CoverImageView(item: entry, cornerRadius: 5)
                        .frame(width: coverSize.width, height: coverSize.height)
                        .shadow(color: .black.opacity(Theme.shadowAlpha(scheme)), radius: 4, y: 3)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.title)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text(queueMeta)
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
                            .padding(.top, 4)
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    if entry.progressTotal > 0 {
                        Text("\(Int(entry.progress * 100))%")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.amber)
                    } else {
                        Text("品味中")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.ink3)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .frame(minWidth: width, maxWidth: width ?? .infinity)
                .background(Theme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.rule, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            // 概念稿 .qitem:hover：上浮 2px
            .onHover { hovered = $0 }
            .offset(y: hovered ? -2 : 0)
            .animation(.easeOut(duration: 0.18), value: hovered)
        }

        private var queueMeta: String {
            var parts = [entry.type.tabTitle]
            if let creator = entry.creator { parts.append(creator) }
            if let year = entry.year { parts.append(String(year)) }
            if entry.progressTotal > 0 {
                parts.append(entry.progressText)
            }
            return parts.joined(separator: " · ")
        }
    }
}
