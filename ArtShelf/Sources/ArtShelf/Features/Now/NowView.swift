import SwiftUI

/// 「此刻」首页：Hero（正在品味）+ 进行中队列 + 三类精选 + 数据条
///
/// 整页共享 Hero 封面的环境光——全窗连续氛围场（封面虚化铺底 + 主色径向光团 +
/// 纵向向画布色沉降），向上溢出至透明顶栏后方。分节标题与 Hero 处在同一光场里，
/// 没有各自为战的色块，也就没有横向明暗分层。
struct NowView: View {

    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    /// Hero 封面主色（由 NowHeroView 取色上报，驱动整页氛围场与 Hero 封面光晕）
    @State private var heroGlow: Color?

    /// 进行中藏品，按最近品味时间倒序（第一个即 Hero）
    private var inProgress: [MediaItem] {
        store.items
            .filter { $0.status == .inProgress }
            .sorted { ($0.lastTastedAt ?? .distantPast) > ($1.lastTastedAt ?? .distantPast) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let hero = inProgress.first {
                    NowHeroView(item: hero, queue: Array(inProgress.dropFirst()), glowColor: $heroGlow)
                } else {
                    emptyHero
                }

                ForEach(MediaType.allCases) { type in
                    MediaSectionRow(
                        type: type,
                        title: sectionTitle(for: type),
                        subtitle: sectionSubtitle(for: type),
                        items: featured(for: type),
                        totalCount: store.items.filter { $0.type == type }.count
                    )
                }

                StatsStrip(items: store.items)
                    .padding(.top, 20)
            }
        }
        .scrollIndicators(.hidden)
        .background(alignment: .top) { pageAmbient }
    }

    // MARK: - 整页氛围场

    /// 全窗连续氛围：封面超大虚化铺底 + 三层径向光团（沿用 Hero 配方），
    /// 再以纵向渐变向画布色沉降收敛。整体向上溢出 80pt 至透明顶栏后方，
    /// 窗口顶部整片处在同一光场中，页面自上而下无水平分界。
    @ViewBuilder
    private var pageAmbient: some View {
        if let hero = inProgress.first {
            GeometryReader { geo in
                ZStack {
                    ZStack {
                        // 封面自身超大虚化铺底
                        CoverImageView(item: hero, cornerRadius: 0, showsPlaceholderText: false)
                            .scaledToFill()
                            .blur(radius: 100)
                            .opacity(0.40)

                        // 三层戏剧化径向渐变（对齐 Demo .hero .ambient，圆心按全窗高度重排）
                        if let heroGlow {
                            let secondary = derivedSecondaryColor(from: heroGlow)
                            // 1. 左侧大面积主色光团
                            RadialGradient(
                                colors: [heroGlow.opacity(0.60), .clear],
                                center: .init(x: 0.22, y: 0.24),
                                startRadius: 30, endRadius: 640
                            )
                            // 2. 右下方深层冷暖对比次色
                            RadialGradient(
                                colors: [secondary.opacity(0.48), .clear],
                                center: .init(x: 0.70, y: 0.72),
                                startRadius: 40, endRadius: 560
                            )
                            // 3. 右上方琥珀暖调微光
                            RadialGradient(
                                colors: [Theme.amberBtn.opacity(0.22), .clear],
                                center: .init(x: 0.85, y: 0.08),
                                startRadius: 20, endRadius: 400
                            )
                        }
                    }
                    .opacity(Theme.ambientOpacity(scheme))

                    // 纵向沉降：底部向画布色收敛，沉降连续无拐点（不参与光效缩放）
                    LinearGradient(
                        stops: [
                            .init(color: Theme.bg.opacity(0), location: 0.10),
                            .init(color: Theme.bg.opacity(0.45), location: 0.55),
                            .init(color: Theme.bg.opacity(0.72), location: 0.92)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                }
                .frame(width: geo.size.width, height: geo.size.height + 80)
                .offset(y: -80)
            }
            .allowsHitTesting(false)
        }
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

    // MARK: - 空态

    private var emptyHero: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.amber)
            Text("此刻暂无进行中的作品")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("从片库、唱片或书架中挑一件开始品味，它就会出现在这里。")
                .font(Theme.body)
                .foregroundStyle(Theme.ink2)
            Button {
                appState.tab = .movies
            } label: {
                Text("去逛逛馆藏")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.amberOn)
                    .padding(.horizontal, 20)
                    .frame(height: 34)
                    .background(Theme.amberBtn)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    // MARK: - 精选行数据

    /// 精选口径：进行中优先（按最近品味），其余按最近浏览 / 添加倒序，取前 6
    private func featured(for type: MediaType) -> [MediaItem] {
        let typed = store.items.filter { $0.type == type }
        let tasting = typed
            .filter { $0.status == .inProgress }
            .sorted { ($0.lastTastedAt ?? .distantPast) > ($1.lastTastedAt ?? .distantPast) }
        let rest = typed
            .filter { $0.status != .inProgress }
            .sorted {
                ($0.lastViewedDate ?? $0.dateAdded) > ($1.lastViewedDate ?? $1.dateAdded)
            }
        return Array((tasting + rest).prefix(6))
    }

    private func sectionTitle(for type: MediaType) -> String {
        switch type {
        case .movie: return "片库精选"
        case .music: return "唱片墙"
        case .book:  return "书架"
        }
    }

    private func sectionSubtitle(for type: MediaType) -> String {
        switch type {
        case .movie: return "CINEMA"
        case .music: return "VINYL"
        case .book:  return "LIBRARY"
        }
    }
}

// MARK: - 分区横滑行

struct MediaSectionRow: View {

    let type: MediaType
    let title: String
    let subtitle: String
    let items: [MediaItem]
    let totalCount: Int

    @Environment(AppState.self) private var appState

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(Theme.sectionTitle)
                        .foregroundStyle(Theme.ink)
                    Text("\(subtitle) · \(totalCount)")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(0.8)
                        .foregroundStyle(Theme.ink3)
                    Spacer()
                    Button("全部 ›") {
                        if let tab = AppTab.allCases.first(where: { $0.mediaType == type }) {
                            appState.tab = tab
                        }
                    }
                    .font(Theme.control)
                    .foregroundStyle(Theme.ink2)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.contentPadding)
                .padding(.bottom, 20)

                ScrollView(.horizontal) {
                    HStack(spacing: Theme.rowSpacing) {
                        ForEach(items) { item in
                            MediaCardView(item: item)
                        }
                    }
                    .padding(.horizontal, Theme.contentPadding)
                    // 概念稿 .row padding：上 4 防光晕裁切、底 18 留出卡后呼吸位
                    .padding(.top, 4)
                    .padding(.bottom, 18)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.top, Theme.sectionSpacing)
        }
    }
}

// MARK: - 数据条

struct StatsStrip: View {

    let items: [MediaItem]

    private var inProgressCount: Int { items.filter { $0.status == .inProgress }.count }

    private var addedThisMonth: Int { LibraryStats.addedThisMonth(items) }

    private var noteCount: Int { LibraryStats.noteCount(items) }

    private var averageRating: Double? { LibraryStats.averageRating(items) }

    var body: some View {
        HStack(spacing: 0) {
            stat(value: "\(items.count)", unit: "件", label: "馆藏总量")
            divider
            stat(value: "\(inProgressCount)", unit: "件", label: "此刻进行中")
            divider
            stat(value: "\(addedThisMonth)", unit: "件", label: "本月新增", badge: addedThisMonth > 0 ? "▲ \(addedThisMonth)" : nil)
            divider
            stat(value: "\(noteCount)", unit: "条", label: "策展笔记")
            divider
            stat(value: averageRating.map { String(format: "%.1f", $0) } ?? "—",
                 unit: averageRating == nil ? "" : "分", label: "平均评分")
        }
        .padding(.vertical, 18)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.rule, lineWidth: 1)
        )
        .padding(.horizontal, Theme.contentPadding)
        .padding(.bottom, 34)
    }

    private func stat(value: String, unit: String, label: String, badge: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.ink3)
                }
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.positive)
                        .padding(.leading, 3)
                }
            }
            Text(label)
                .font(.system(size: 11))
                .tracking(1)
                .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
    }

    private var divider: some View {
        Rectangle().fill(Theme.rule).frame(width: 1, height: 40)
    }
}
