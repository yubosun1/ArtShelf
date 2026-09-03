import SwiftUI

/// 「统计」页：Bento Grid 沉浸品味仪表盘
///
/// 口径约束（见 docs/product-design.md §4.5）：所有指标一律从现有字段
/// 直接派生，不做「品味时长」类指标。
///
/// 视觉架构：
/// - 顶部 Overview KPI Strip（6 个核心指标精致卡片列）
/// - 中层双栏等高 Bento 卡（馆藏与状态画像卡 vs 评分与创作者卡）
/// - 底层时光足迹卡（月度堆叠趋势 + 12 周日历热力图）
struct StatsView: View {

    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    // MARK: - 派生统计

    /// 本月新增件数
    private var addedThisMonth: Int { LibraryStats.addedThisMonth(store.items) }

    /// 策展笔记总数
    private var noteCount: Int { LibraryStats.noteCount(store.items) }

    /// 平均评分（仅统计已评分条目，即 rating > 0）
    private var averageRating: Double? { LibraryStats.averageRating(store.items) }

    /// 已评分条目数
    private var ratedCount: Int { store.items.filter { $0.rating > 0 }.count }

    /// 完成率（已完成 / 总数）
    private var completionRate: Int? {
        guard !store.items.isEmpty else { return nil }
        let done = store.items.filter { $0.status == .completed }.count
        return Int(round(Double(done) / Double(store.items.count) * 100))
    }

    /// 重温总次数
    private var replayTotal: Int { store.items.reduce(0) { $0 + $1.replayCount } }

    /// 最常品味类型（进行中 + 已完成最多者；尚未开品味任何条目时为 nil）
    private var mostTastedType: MediaType? {
        let tasted = store.items.filter { $0.status != .planned }
        guard !tasted.isEmpty else { return nil }
        return MediaType.allCases.max { a, b in
            tasted.filter { $0.type == a }.count < tasted.filter { $0.type == b }.count
        }
    }

    /// 热力图起点：本周周首日往前 11 周的周首日（共 12 周 × 7 天）
    private var heatmapStart: Date {
        let cal = Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        return cal.date(byAdding: .weekOfYear, value: -11, to: weekStart)!
    }

    /// 每日收录计数（键 = 自热力图起点起的天数偏移）
    private var heatmapCounts: [Int: Int] {
        let cal = Calendar.current
        var counts: [Int: Int] = [:]
        for item in store.items {
            let offset = cal.dateComponents([.day], from: heatmapStart, to: cal.startOfDay(for: item.dateAdded)).day ?? -1
            if offset >= 0 { counts[offset, default: 0] += 1 }
        }
        return counts
    }

    /// 近 6 个月收录（旧→新）：月份标签 + 各类型件数
    private var monthlyTrend: [(label: String, total: Int, counts: [MediaType: Int])] {
        let cal = Calendar.current
        var months: [(String, Int, [MediaType: Int])] = []
        for back in (0..<6).reversed() {
            let monthDate = cal.date(byAdding: .month, value: -back, to: Date())!
            let comps = cal.dateComponents([.year, .month], from: monthDate)
            var counts: [MediaType: Int] = [:]
            for item in store.items {
                let ic = cal.dateComponents([.year, .month], from: item.dateAdded)
                if ic.year == comps.year && ic.month == comps.month {
                    counts[item.type, default: 0] += 1
                }
            }
            months.append(("\(comps.month!)月", counts.values.reduce(0, +), counts))
        }
        return months
    }

    /// 创作者聚合榜（收录件数降序前 5；并列按名字排序保持稳定）
    private var topCreators: [(name: String, count: Int, type: MediaType)] {
        var counts: [String: Int] = [:]
        var types: [String: [MediaType: Int]] = [:]
        for item in store.items {
            guard let creator = item.creator?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !creator.isEmpty else { continue }
            counts[creator, default: 0] += 1
            types[creator, default: [:]][item.type, default: 0] += 1
        }
        return counts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(5)
            .map { name, count in
                let dominant = (types[name] ?? [:]).max { $0.value < $1.value }?.key ?? .movie
                return (name, count, dominant)
            }
    }

    // MARK: - 页面主体

    var body: some View {
        ZStack(alignment: .top) {
            statsAmbient
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if store.items.isEmpty {
                        emptyState
                    } else {
                        dashboardContent
                    }
                }
                .padding(.horizontal, Theme.contentPadding)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - 整页氛围场

    private var statsAmbient: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [Theme.amberBtn.opacity(0.08), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                AmbientGlow(color: Theme.amberBtn, radius: 380)
                    .frame(width: 980, height: 820)
                    .offset(x: -180, y: -280)
            }
            .opacity(Theme.ambientOpacity(scheme))
            .frame(width: geo.size.width, height: geo.size.height + 80)
            .offset(y: -80)
        }
        .allowsHitTesting(false)
    }

    /// 页头：小标 + 标题 + 导语
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("STATS")
                .font(Theme.kicker)
                .tracking(3)
                .foregroundStyle(Theme.ink3)
            Text("统计")
                .font(Theme.sectionTitle)
                .foregroundStyle(Theme.ink)
            Text("你的品味数据全部来自本地馆藏，一目了然。")
                .font(Theme.body)
                .foregroundStyle(Theme.ink2)
        }
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    // MARK: - 仪表盘主体

    private var dashboardContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1. 顶部概览指标行
            overviewStrip

            // 2. 中层双栏等高 Bento 卡片
            HStack(alignment: .top, spacing: 16) {
                collectionAndStatusCard
                ratingsAndCreatorsCard
            }

            // 3. 底层时光足迹全宽卡片
            timelineCard
        }
        .padding(.bottom, 40)
    }

    // MARK: - 1. 顶部概览指标行 (Overview KPI Strip)

    private var overviewStrip: some View {
        HStack(spacing: 10) {
            overviewItem(
                icon: "calendar.badge.plus",
                iconColor: Theme.amber,
                value: "\(addedThisMonth)",
                unit: "件",
                label: "本月新增"
            )
            overviewItem(
                icon: "note.text",
                iconColor: Color(nsColor: Theme.hex(0x5B82F6)),
                value: "\(noteCount)",
                unit: "条",
                label: "策展笔记"
            )
            overviewItem(
                icon: "star.fill",
                iconColor: Theme.amber,
                value: averageRating.map { String(format: "%.1f", $0) } ?? "—",
                unit: averageRating == nil ? "" : "分",
                label: "平均评分",
                footnote: ratedCount > 0 ? "\(ratedCount) 件已评" : nil
            )
            overviewItem(
                icon: "checkmark.circle.fill",
                iconColor: Color(nsColor: Theme.hex(0x43B581)),
                value: completionRate.map { "\($0)" } ?? "—",
                unit: completionRate == nil ? "" : "%",
                label: "品味完成率"
            )
            overviewItem(
                icon: "arrow.triangle.2.circlepath",
                iconColor: Color(nsColor: Theme.hex(0x9A5BF6)),
                value: "\(replayTotal)",
                unit: "次",
                label: "重温品味"
            )
            overviewItem(
                icon: "sparkles",
                iconColor: mostTastedType.map(typeColor) ?? Theme.amber,
                value: mostTastedType?.rawValue ?? "—",
                unit: "",
                label: "偏好类型",
                accent: mostTastedType.map(typeColor)
            )
        }
    }

    private func overviewItem(
        icon: String,
        iconColor: Color,
        value: String,
        unit: String,
        label: String,
        footnote: String? = nil,
        accent: Color? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 20, height: 20)
                    .background(iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                Spacer()
                if let footnote {
                    Text(footnote)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.ink3)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(accent ?? Theme.ink)
                    .lineLimit(1)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Theme.ink3)
                }
            }

            Text(label)
                .font(.system(size: 10))
                .tracking(0.2)
                .foregroundStyle(Theme.ink3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.rule, lineWidth: 1)
        )
    }

    // MARK: - 2. 馆藏与状态画像卡 (Collection & Status)

    private var collectionAndStatusCard: some View {
        StatsCard(
            icon: "square.grid.2x2.fill",
            iconColor: Color(nsColor: Theme.hex(0x5B82F6)),
            title: "馆藏与品味状态",
            subtitle: "COLLECTION & STATUS",
            note: "\(store.items.count) 件馆藏"
        ) {
            VStack(spacing: 16) {
                // 上半部分：馆藏分类构成
                HStack(spacing: 22) {
                    donutChart
                    VStack(spacing: 10) {
                        ForEach(MediaType.allCases) { type in
                            mediaTypeRow(type: type)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // 细分隔线
                Rectangle()
                    .fill(Theme.rule)
                    .frame(height: 1)

                // 下半部分：品味状态流转
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("品味进展")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                        Spacer()
                    }

                    // 堆叠胶囊条
                    statusStackBar

                    // 状态徽标与数量
                    HStack(spacing: 6) {
                        ForEach(MediaStatus.allCases, id: \.self) { status in
                            statusTag(status: status)
                        }
                    }
                }
            }
        }
    }

    /// Donut 环形图
    private var donutChart: some View {
        let total = max(1, store.items.count)
        return ZStack {
            Circle()
                .stroke(Theme.track, lineWidth: 14)
            ForEach(Array(MediaType.allCases.enumerated()), id: \.element) { index, type in
                let range = typeFractionRange(index: index, total: total)
                Circle()
                    .trim(from: range.start, to: range.end)
                    .stroke(typeColor(type), style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 0) {
                Text("\(store.items.count)")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("馆藏")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.ink3)
            }
        }
        .frame(width: 96, height: 96)
    }

    private func typeFractionRange(index: Int, total: Int) -> (start: CGFloat, end: CGFloat) {
        let start = MediaType.allCases.prefix(index).reduce(0.0) { $0 + fractionOfType($1, total: total) }
        return (start, start + fractionOfType(MediaType.allCases[index], total: total))
    }

    private func fractionOfType(_ type: MediaType, total: Int) -> CGFloat {
        CGFloat(store.items.filter { $0.type == type }.count) / CGFloat(total)
    }

    /// 媒体类型行（带比例条与数字）
    private func mediaTypeRow(type: MediaType) -> some View {
        let count = store.items.filter { $0.type == type }.count
        let total = max(1, store.items.count)
        let fraction = Double(count) / Double(total)
        let color = typeColor(type)

        return VStack(spacing: 4) {
            HStack(spacing: 7) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(type.rawValue)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(count) 件")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.ink2)
                Text("\(Int(round(fraction * 100)))%")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Theme.ink3)
                    .frame(width: 32, alignment: .trailing)
            }
            // 细长比例条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule().fill(color).frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 4)
        }
    }

    /// 状态堆叠胶囊条
    private var statusStackBar: some View {
        let total = Double(max(1, store.items.count))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                HStack(spacing: 0) {
                    ForEach(MediaStatus.allCases, id: \.self) { status in
                        let count = store.items.filter { $0.status == status }.count
                        Capsule()
                            .fill(Theme.statusColors(status).bg)
                            .frame(width: max(0, geo.size.width * Double(count) / total))
                    }
                }
            }
        }
        .frame(height: 7)
    }

    /// 状态标签条目
    private func statusTag(status: MediaStatus) -> some View {
        let count = store.items.filter { $0.status == status }.count
        let fraction = Double(count) / Double(max(1, store.items.count))
        let colors = Theme.statusColors(status)

        return HStack(spacing: 5) {
            Circle().fill(colors.tx).frame(width: 5, height: 5)
            Text(statusName(status))
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
            Text("\(count)")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(Theme.ink2)
            Text("(\(Int(round(fraction * 100)))%)")
                .font(.system(size: 9))
                .foregroundStyle(Theme.ink3)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(Theme.well)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: - 3. 评价与偏爱创作者卡 (Ratings & Top Creators)

    private var ratingsAndCreatorsCard: some View {
        StatsCard(
            icon: "heart.fill",
            iconColor: Theme.amber,
            title: "评价与偏爱创作者",
            subtitle: "RATINGS & CREATORS",
            note: averageRating.map { String(format: "均分 %.1f ★", $0) }
        ) {
            VStack(spacing: 16) {
                // 上半部分：5 星评分水平分布条
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("星级分布")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                        Spacer()
                        if ratedCount > 0 {
                            Text("已评 \(ratedCount) 件")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.ink3)
                        }
                    }

                    if ratedCount == 0 {
                        HStack {
                            Spacer()
                            Text("还没有记录星级评分")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.ink3)
                                .padding(.vertical, 16)
                            Spacer()
                        }
                    } else {
                        VStack(spacing: 4) {
                            ForEach((1...5).reversed(), id: \.self) { stars in
                                ratingBarRow(stars: stars)
                            }
                        }
                    }
                }

                // 细分隔线
                Rectangle()
                    .fill(Theme.rule)
                    .frame(height: 1)

                // 下半部分：常收录创作者 TOP 5
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("偏爱创作者")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                        Spacer()
                        Text("收录 TOP 5")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.ink3)
                    }

                    if topCreators.isEmpty {
                        HStack {
                            Spacer()
                            Text("暂无创作者信息")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.ink3)
                                .padding(.vertical, 16)
                            Spacer()
                        }
                    } else {
                        let maxCount = max(1, topCreators.first?.count ?? 1)
                        VStack(spacing: 5) {
                            ForEach(Array(topCreators.enumerated()), id: \.offset) { index, creator in
                                creatorCompactRow(rank: index + 1, creator: creator, maxCount: maxCount)
                            }
                        }
                    }
                }
            }
        }
    }

    /// 评分水平条单行 (5星 -> 1星)
    private func ratingBarRow(stars: Int) -> some View {
        let count = store.items.filter { $0.rating == stars }.count
        let total = max(1, ratedCount)
        let fraction = Double(count) / Double(total)
        let color = Theme.amber.opacity(min(1, 0.35 + 0.13 * Double(stars)))

        return HStack(spacing: 7) {
            HStack(spacing: 2) {
                Text("\(stars)")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                Image(systemName: "star.fill")
                    .font(.system(size: 7.5))
                    .foregroundStyle(Theme.amber)
            }
            .frame(width: 24, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule().fill(color).frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 5)

            HStack(spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(count > 0 ? Theme.ink : Theme.ink3)
            }
            .frame(width: 20, alignment: .trailing)
        }
    }

    /// 创作者紧凑行
    private func creatorCompactRow(rank: Int, creator: (name: String, count: Int, type: MediaType), maxCount: Int) -> some View {
        let fraction = Double(creator.count) / Double(maxCount)
        let color = typeColor(creator.type)

        return HStack(spacing: 7) {
            // 名次标
            Text("\(rank)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(rank == 1 ? Theme.amber : (rank <= 3 ? Theme.ink2 : Theme.ink3))
                .frame(width: 12, alignment: .center)

            // 类型色点
            Circle().fill(color).frame(width: 5, height: 5)

            // 名字
            Text(creator.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .frame(maxWidth: 130, alignment: .leading)

            // 比例条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule().fill(color.opacity(0.85)).frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 5)

            // 件数
            Text("\(creator.count) 件")
                .font(.system(size: 10))
                .foregroundStyle(Theme.ink3)
                .frame(width: 28, alignment: .trailing)
        }
    }

    // MARK: - 4. 底层时光足迹卡片 (Timeline & Footprints)

    private var timelineCard: some View {
        let counts = heatmapCounts
        let total = counts.values.reduce(0, +)

        return StatsCard(
            icon: "clock.arrow.circlepath",
            iconColor: Color(nsColor: Theme.hex(0x43B581)),
            title: "时光足迹与收录节奏",
            subtitle: "TIMELINE & FOOTPRINTS",
            note: "近 12 周共收录 \(total) 件"
        ) {
            HStack(alignment: .top, spacing: 28) {
                // 左区：近 6 个月月度趋势
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("月度收录趋势")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                        Spacer()
                        trendLegend
                    }

                    monthlyTrendView
                }
                .frame(maxWidth: .infinity)

                // 纵向分割发丝线 (固定高度与对齐)
                Rectangle()
                    .fill(Theme.rule)
                    .frame(width: 1, height: 120)

                // 右区：近 12 周热力图
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("收录热力网格")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                        Spacer()
                        heatmapLegend
                    }

                    heatmapGrid(counts: counts)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// 月度收录趋势柱状图
    private var monthlyTrendView: some View {
        let months = monthlyTrend
        let maxCount = max(1, months.map(\.total).max() ?? 0)

        return HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(months.enumerated()), id: \.offset) { _, month in
                VStack(spacing: 5) {
                    Text("\(month.total)")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(month.total > 0 ? Theme.ink2 : Theme.ink3)

                    ZStack(alignment: .bottom) {
                        trendStackedBar(month: month, maxCount: maxCount)
                    }
                    .frame(height: 64)

                    Text(month.label)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.ink3)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func trendStackedBar(month: (label: String, total: Int, counts: [MediaType: Int]), maxCount: Int) -> some View {
        let barHeight = max(6, 64 * CGFloat(month.total) / CGFloat(maxCount))
        return Group {
            if month.total == 0 {
                Capsule().fill(Theme.track).frame(width: 16, height: 3)
            } else {
                VStack(spacing: 0) {
                    ForEach(MediaType.allCases) { type in
                        let count = month.counts[type] ?? 0
                        if count > 0 {
                            Rectangle()
                                .fill(typeColor(type))
                                .frame(height: barHeight * CGFloat(count) / CGFloat(month.total))
                        }
                    }
                }
                .frame(width: 16, height: barHeight)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 3, style: .continuous))
            }
        }
    }

    private var trendLegend: some View {
        HStack(spacing: 7) {
            ForEach(MediaType.allCases) { type in
                HStack(spacing: 3) {
                    Circle().fill(typeColor(type)).frame(width: 5, height: 5)
                    Text(type.rawValue)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.ink3)
                }
            }
        }
    }

    /// 12 周日历热力图
    private func heatmapGrid(counts: [Int: Int]) -> some View {
        let side: CGFloat = 12
        let spacing: CGFloat = 3.5

        return HStack(alignment: .top, spacing: 6) {
            // 7 天精确对齐星期标 (周一、三、五、日)
            VStack(spacing: spacing) {
                ForEach(0..<7, id: \.self) { day in
                    Group {
                        switch day {
                        case 0: Text("一")
                        case 2: Text("三")
                        case 4: Text("五")
                        case 6: Text("日")
                        default: Text("")
                        }
                    }
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(Theme.ink3)
                    .frame(width: 12, height: side)
                }
            }

            // 12 列网格
            HStack(spacing: spacing) {
                ForEach(0..<12, id: \.self) { week in
                    VStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { weekday in
                            heatmapCell(offset: week * 7 + weekday, counts: counts, side: side)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 7 * side + 6 * spacing)
    }

    private func heatmapCell(offset: Int, counts: [Int: Int], side: CGFloat) -> some View {
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: offset, to: heatmapStart)!
        let isFuture = date > cal.startOfDay(for: Date())
        let count = isFuture ? 0 : (counts[offset] ?? 0)

        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(isFuture ? Color.clear : heatColor(count))
            .frame(width: side, height: side)
            .help("\(date.formatted(.dateTime.month(.twoDigits).day(.twoDigits))) 收录 \(count) 件")
    }

    private func heatColor(_ count: Int) -> Color {
        switch count {
        case 0:  return Theme.track
        case 1:  return Theme.amber.opacity(0.35)
        case 2:  return Theme.amber.opacity(0.65)
        default: return Theme.amber
        }
    }

    private var heatmapLegend: some View {
        HStack(spacing: 3) {
            Text("少")
                .font(.system(size: 9))
                .foregroundStyle(Theme.ink3)
            ForEach([0, 1, 2, 3], id: \.self) { level in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(heatColor(level))
                    .frame(width: 7.5, height: 7.5)
            }
            Text("多")
                .font(.system(size: 9))
                .foregroundStyle(Theme.ink3)
        }
    }

    // MARK: - 通用辅助

    private func typeColor(_ type: MediaType) -> Color {
        switch type {
        case .movie: return Theme.typeMovie
        case .music: return Theme.typeMusic
        case .book:  return Theme.typeBook
        }
    }

    private func statusName(_ status: MediaStatus) -> String {
        switch status {
        case .planned:    return "待品味"
        case .inProgress: return "进行中"
        case .completed:  return "已完成"
        }
    }

    // MARK: - 空态

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.amber)
            Text("馆藏还空着，统计尚无内容")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("收录第一件藏品后，这里会开始记录你的品味足迹。")
                .font(Theme.body)
                .foregroundStyle(Theme.ink2)
            Button {
                appState.showingAdd = true
            } label: {
                Text("去收录")
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
        .padding(.vertical, 72)
    }
}

// MARK: - Bento 统计卡片通用容器

private struct StatsCard<Content: View>: View {
    let icon: String?
    let iconColor: Color
    let title: String
    let subtitle: String
    let note: String?
    let content: Content

    init(
        icon: String? = nil,
        iconColor: Color = Theme.amber,
        title: String,
        subtitle: String,
        note: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.note = note
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 卡片头部
            HStack(alignment: .center, spacing: 9) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(iconColor)
                        .frame(width: 22, height: 22)
                        .background(iconColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5.5, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(title)
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text(subtitle)
                            .font(.system(size: 9.5, weight: .semibold))
                            .tracking(0.6)
                            .foregroundStyle(Theme.ink3)
                    }
                }
                Spacer()
                if let note {
                    Text(note)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Theme.ink3)
                }
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: Theme.panelCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.panelCorner, style: .continuous)
                .stroke(Theme.rule, lineWidth: 1)
        )
    }
}