import SwiftUI

/// 「统计」页：Editorial 沉浸画册式品味回顾
///
/// 设计哲学：
/// - 零卡片壳、零多余边框，纯净数据画布与暗房光晕融为一体（去除 AI 仪表盘盒子感）
/// - 靠空间留白、轴线对齐（Grid Alignment）与克制发丝线（Hairline Rules）建立坚实秩序
/// - 热力图全宽自适应展开（过去 1 年 52 周），精确标注月份横轴与星期纵轴，绝不超出容器
/// - 彻底移除冗余的月度柱状图，页面极简纯粹、呼吸感充沛
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

    /// 热力图起点：本周周首日往前 51 周的周首日（共 52 周 × 7 天，整整 1 年足迹）
    private var heatmapStart: Date {
        let cal = Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        return cal.date(byAdding: .weekOfYear, value: -51, to: weekStart)!
    }

    /// 每日收录计数（键 = 自热力图起点起的天数偏移）
    private var heatmapCounts: [Int: Int] {
        let cal = Calendar.current
        var counts: [Int: Int] = [:]
        for item in store.items {
            let offset = cal.dateComponents([.day], from: heatmapStart, to: cal.startOfDay(for: item.dateAdded)).day ?? -1
            if offset >= 0 && offset < 52 * 7 {
                counts[offset, default: 0] += 1
            }
        }
        return counts
    }

    /// 热力图月份横轴标签：根据当前动态计算出的格子 side 和 spacing 唯一定位
    private func heatmapMonthLabels(side: CGFloat, spacing: CGFloat) -> [(offset: CGFloat, label: String)] {
        let cal = Calendar.current
        var labels: [(CGFloat, String)] = []
        var lastMonth = -1
        var lastOffset: CGFloat = -100

        for week in 0..<52 {
            let weekDate = cal.date(byAdding: .weekOfYear, value: week, to: heatmapStart)!
            let month = cal.component(.month, from: weekDate)
            let offset = CGFloat(week) * (side + spacing)
            if month != lastMonth && (offset - lastOffset) >= 36 {
                labels.append((offset, "\(month)月"))
                lastMonth = month
                lastOffset = offset
            }
        }
        return labels
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
                        editorialContent
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
        VStack(alignment: .leading, spacing: 5) {
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
        .padding(.top, Theme.sectionSpacing)
        .padding(.bottom, 24)
    }

    // MARK: - Editorial 画布主体

    private var editorialContent: some View {
        VStack(alignment: .leading, spacing: 32) {
            // 1. 顶部概览数据排（无边框，优雅发丝线分割）
            overviewRow

            // 2. 中层双栏结构（完全等高对齐）
            HStack(alignment: .top, spacing: 44) {
                collectionAndStatusSection
                ratingsAndCreatorsSection
            }

            // 3. 底层时光足迹（全宽响应式热力图，彻底移除柱状图）
            timelineSection
        }
        .padding(.bottom, 48)
    }

    // MARK: - 1. 概览数据排 (Overview Row)

    private var overviewRow: some View {
        VStack(spacing: 0) {
            // 顶发丝线
            Rectangle().fill(Theme.rule).frame(height: 1)

            HStack(spacing: 0) {
                overviewItem(label: "本月新增", value: "\(addedThisMonth)", unit: "件")
                ruleDivider
                overviewItem(label: "策展笔记", value: "\(noteCount)", unit: "条")
                ruleDivider
                overviewItem(
                    label: "平均评分",
                    value: averageRating.map { String(format: "%.1f", $0) } ?? "—",
                    unit: averageRating == nil ? "" : "分",
                    subtext: ratedCount > 0 ? "\(ratedCount) 件已评" : nil
                )
                ruleDivider
                overviewItem(
                    label: "品味完成率",
                    value: completionRate.map { "\($0)" } ?? "—",
                    unit: completionRate == nil ? "" : "%"
                )
                ruleDivider
                overviewItem(label: "重温品味", value: "\(replayTotal)", unit: "次")
                ruleDivider
                overviewItem(
                    label: "偏好类型",
                    value: mostTastedType?.rawValue ?? "—",
                    unit: "",
                    accent: mostTastedType.map(typeColor)
                )
            }
            .padding(.vertical, 16)

            // 底发丝线
            Rectangle().fill(Theme.rule).frame(height: 1)
        }
    }

    private var ruleDivider: some View {
        Rectangle()
            .fill(Theme.rule)
            .frame(width: 1, height: 32)
    }

    private func overviewItem(
        label: String,
        value: String,
        unit: String,
        subtext: String? = nil,
        accent: Color? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(accent ?? Theme.ink)
                    .lineLimit(1)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.ink3)
                }
            }
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 11))
                    .tracking(0.5)
                    .foregroundStyle(Theme.ink3)
                if let subtext {
                    Text("· \(subtext)")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.ink3.opacity(0.8))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }

    // MARK: - 章节页眉组件 (Section Header)

    private func sectionTitleRow(title: String, subtitle: String, note: String? = nil) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(Theme.sectionTitle)
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(Theme.ink3)
                Spacer()
                if let note {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.ink3)
                }
            }
            Rectangle().fill(Theme.rule).frame(height: 1)
        }
    }

    // MARK: - 2. 馆藏与品味状态 (Collection & Status)

    private var collectionAndStatusSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitleRow(title: "馆藏与品味状态", subtitle: "COLLECTION & STATUS", note: "\(store.items.count) 件馆藏")

            // 上半部分：分类构成
            HStack(spacing: 28) {
                donutChart
                VStack(spacing: 11) {
                    ForEach(MediaType.allCases) { type in
                        mediaTypeRow(type: type)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 4)

            // 次级分隔线
            Rectangle()
                .fill(Theme.rule.opacity(0.7))
                .frame(height: 1)
                .padding(.vertical, 2)

            // 下半部分：品味进展
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("品味进展")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.ink2)
                    Spacer()
                }

                // 纯净堆叠进度条
                statusStackBar

                // 三列纯排版数据说明（无盒子背景）
                HStack(spacing: 12) {
                    ForEach(MediaStatus.allCases, id: \.self) { status in
                        statusInfoColumn(status: status)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var donutChart: some View {
        let total = max(1, store.items.count)
        return ZStack {
            Circle()
                .stroke(Theme.track, lineWidth: 16)
            ForEach(Array(MediaType.allCases.enumerated()), id: \.element) { index, type in
                let range = typeFractionRange(index: index, total: total)
                Circle()
                    .trim(from: range.start, to: range.end)
                    .stroke(typeColor(type), style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 1) {
                Text("\(store.items.count)")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("馆藏")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.ink3)
            }
        }
        .frame(width: 104, height: 104)
    }

    private func typeFractionRange(index: Int, total: Int) -> (start: CGFloat, end: CGFloat) {
        let start = MediaType.allCases.prefix(index).reduce(0.0) { $0 + fractionOfType($1, total: total) }
        return (start, start + fractionOfType(MediaType.allCases[index], total: total))
    }

    private func fractionOfType(_ type: MediaType, total: Int) -> CGFloat {
        CGFloat(store.items.filter { $0.type == type }.count) / CGFloat(total)
    }

    private func mediaTypeRow(type: MediaType) -> some View {
        let count = store.items.filter { $0.type == type }.count
        let total = max(1, store.items.count)
        let fraction = Double(count) / Double(total)
        let color = typeColor(type)

        return VStack(spacing: 5) {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(type.rawValue)
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(count) 件")
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink2)
                Text("\(Int(round(fraction * 100)))%")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.ink3)
                    .frame(width: 34, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule().fill(color).frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 3.5)
        }
    }

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
        .frame(height: 8)
    }

    private func statusInfoColumn(status: MediaStatus) -> some View {
        let count = store.items.filter { $0.status == status }.count
        let fraction = Double(count) / Double(max(1, store.items.count))
        let colors = Theme.statusColors(status)

        return HStack(spacing: 6) {
            Circle().fill(colors.tx).frame(width: 6, height: 6)
            Text(statusName(status))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
            Text("\(count)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.ink2)
            Text("(\(Int(round(fraction * 100)))%)")
                .font(.system(size: 10))
                .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 3. 评价与偏爱创作者 (Ratings & Creators)

    private var ratingsAndCreatorsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitleRow(
                title: "评价与偏爱创作者",
                subtitle: "RATINGS & CREATORS",
                note: averageRating.map { String(format: "均分 %.1f ★", $0) }
            )

            // 上半部分：星级分布
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("星级分布")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.ink2)
                    Spacer()
                    if ratedCount > 0 {
                        Text("已评 \(ratedCount) 件")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.ink3)
                    }
                }

                if ratedCount == 0 {
                    HStack {
                        Spacer()
                        Text("还没有记录星级评分")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.ink3)
                            .padding(.vertical, 24)
                        Spacer()
                    }
                } else {
                    VStack(spacing: 4.5) {
                        ForEach((1...5).reversed(), id: \.self) { stars in
                            ratingBarRow(stars: stars)
                        }
                    }
                }
            }
            .padding(.top, 4)

            // 次级分隔线
            Rectangle()
                .fill(Theme.rule.opacity(0.7))
                .frame(height: 1)
                .padding(.vertical, 2)

            // 下半部分：偏爱创作者
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("偏爱创作者")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.ink2)
                    Spacer()
                    Text("收录 TOP 5")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.ink3)
                }

                if topCreators.isEmpty {
                    HStack {
                        Spacer()
                        Text("暂无创作者信息")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.ink3)
                            .padding(.vertical, 20)
                        Spacer()
                    }
                } else {
                    let maxCount = max(1, topCreators.first?.count ?? 1)
                    VStack(spacing: 6.5) {
                        ForEach(Array(topCreators.enumerated()), id: \.offset) { index, creator in
                            creatorCompactRow(rank: index + 1, creator: creator, maxCount: maxCount)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func ratingBarRow(stars: Int) -> some View {
        let count = store.items.filter { $0.rating == stars }.count
        let total = max(1, ratedCount)
        let fraction = Double(count) / Double(total)
        let color = Theme.amber.opacity(min(1, 0.35 + 0.13 * Double(stars)))

        return HStack(spacing: 8) {
            HStack(spacing: 2) {
                Text("\(stars)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.amber)
            }
            .frame(width: 26, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule().fill(color).frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 5)

            HStack(spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(count > 0 ? Theme.ink : Theme.ink3)
            }
            .frame(width: 22, alignment: .trailing)
        }
    }

    private func creatorCompactRow(rank: Int, creator: (name: String, count: Int, type: MediaType), maxCount: Int) -> some View {
        let fraction = Double(creator.count) / Double(maxCount)
        let color = typeColor(creator.type)

        return HStack(spacing: 8) {
            Text("\(rank)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(rank == 1 ? Theme.amber : (rank <= 3 ? Theme.ink2 : Theme.ink3))
                .frame(width: 14, alignment: .center)

            Circle().fill(color).frame(width: 6, height: 6)

            Text(creator.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .frame(maxWidth: 140, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule().fill(color.opacity(0.85)).frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 4.5)

            Text("\(creator.count) 件")
                .font(.system(size: 11))
                .foregroundStyle(Theme.ink3)
                .frame(width: 32, alignment: .trailing)
        }
    }

    // MARK: - 4. 时光足迹 (Timeline - 全宽响应式热力图)

    private var timelineSection: some View {
        let counts = heatmapCounts
        let total = counts.values.reduce(0, +)

        return VStack(alignment: .leading, spacing: 16) {
            sectionTitleRow(
                title: "时光足迹",
                subtitle: "TIMELINE",
                note: "过去 1 年共收录 \(total) 件"
            )

            // 全宽响应式收录热力网格（52 周 · 动态自适应当前窗口宽度 · 严禁超出视口）
            heatmapResponsiveSection(counts: counts)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 全宽自适应热力网格：通过 GeometryReader 动态计算方格边长，精准贴合窗口，绝不溢出
    private func heatmapResponsiveSection(counts: [Int: Int]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("收录热力网格")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.ink2)
                Text("ACTIVITY HEATMAP · 过去 1 年")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.6)
                    .foregroundStyle(Theme.ink3)
                Spacer()
                heatmapLegend
            }

            GeometryReader { geo in
                let availableWidth = max(240, geo.size.width)
                let weekCount = 52
                let labelWidth: CGFloat = 14
                let leadSpacing: CGFloat = 8
                let spacing: CGFloat = 3.0
                let gridAvailable = max(100, availableWidth - labelWidth - leadSpacing)
                // 动态计算每个晶格的精确边长（确保 52 列晶格 + 间距永远 <= 可用宽度）
                let side = max(6.0, floor((gridAvailable - CGFloat(weekCount - 1) * spacing) / CGFloat(weekCount)))
                let actualGridWidth = CGFloat(weekCount) * side + CGFloat(weekCount - 1) * spacing

                VStack(alignment: .leading, spacing: 6) {
                    // 顶部月份横轴
                    ZStack(alignment: .leading) {
                        ForEach(Array(heatmapMonthLabels(side: side, spacing: spacing).enumerated()), id: \.offset) { _, item in
                            Text(item.label)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(Theme.ink3)
                                .offset(x: item.offset)
                        }
                    }
                    .frame(width: actualGridWidth, height: 13, alignment: .leading)
                    .padding(.leading, labelWidth + leadSpacing)

                    // 星期导引 + 52 列晶格
                    HStack(alignment: .top, spacing: leadSpacing) {
                        // 星期标签
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
                                .frame(width: labelWidth, height: side)
                            }
                        }

                        // 52 列晶格矩阵
                        HStack(spacing: spacing) {
                            ForEach(0..<weekCount, id: \.self) { week in
                                VStack(spacing: spacing) {
                                    ForEach(0..<7, id: \.self) { weekday in
                                        heatmapCell(offset: week * 7 + weekday, counts: counts, side: side)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 126) // 明确指定高度，确保在各种窗口大小下稳定渲染
        }
    }

    private func heatmapCell(offset: Int, counts: [Int: Int], side: CGFloat) -> some View {
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: offset, to: heatmapStart)!
        let isFuture = date > cal.startOfDay(for: Date())
        let count = isFuture ? 0 : (counts[offset] ?? 0)

        return RoundedRectangle(cornerRadius: max(1.5, side * 0.18), style: .continuous)
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
        HStack(spacing: 4) {
            Text("少")
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.ink3)
            ForEach([0, 1, 2, 3], id: \.self) { level in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(heatColor(level))
                    .frame(width: 8, height: 8)
            }
            Text("多")
                .font(.system(size: 9.5))
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