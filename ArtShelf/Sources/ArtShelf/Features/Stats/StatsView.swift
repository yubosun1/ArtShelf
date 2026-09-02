import SwiftUI

/// 「统计」页：馆藏构成 / 状态分布 / 评分分布 / 概览
///
/// 口径约束（见 docs/product-design.md §4.5）：所有指标一律从现有字段
/// 直接派生，不做「品味时长」类指标。
struct StatsView: View {

    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    // MARK: - 派生统计

    /// 本月新增件数（与「此刻」数据条同口径，见 LibraryStats）
    private var addedThisMonth: Int { LibraryStats.addedThisMonth(store.items) }

    /// 策展笔记总数
    private var noteCount: Int { LibraryStats.noteCount(store.items) }

    /// 平均评分（仅统计已评分条目，即 rating > 0）
    private var averageRating: Double? { LibraryStats.averageRating(store.items) }

    /// 已评分条目数
    private var ratedCount: Int { store.items.filter { $0.rating > 0 }.count }

    /// 评分条形纵轴基准：各星数量最大值（至少 1，防除零）
    private var ratingMaxCount: Int {
        var maxCount = 1
        for stars in 1...5 {
            maxCount = max(maxCount, store.items.filter { $0.rating == stars }.count)
        }
        return maxCount
    }

    /// 完成率（已完成 / 总数）
    private var completionRate: Int? {
        guard !store.items.isEmpty else { return nil }
        let done = store.items.filter { $0.status == .completed }.count
        return Int(round(Double(done) / Double(store.items.count) * 100))
    }

    /// 重温总次数
    private var replayTotal: Int { store.items.reduce(0) { $0 + $1.replayCount } }

    /// 最常品味类型（进行中 + 已完成最多者；尚未开品味任何条目时为 nil）。
    /// 并列时按 MediaType 声明顺序（影视 / 音乐 / 书籍）取先声明者：
    /// max(by:) 对并列比较器返回 false，保留先见到的类型
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

    // MARK: - 页面

    var body: some View {
        ZStack(alignment: .top) {
            statsAmbient
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if store.items.isEmpty {
                        emptyState
                    } else {
                        content
                    }
                }
                .padding(.horizontal, Theme.contentPadding)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - 整页氛围场

    /// 全窗琥珀氛围光（与「库页」同一套光语：顶部淡 wash + 大半径光晕），
    /// 向上溢出 80pt 至透明顶栏后方，统计页顶部与「此刻」「库页」同处连续光场。
    /// 统计页不归属单一类型色，采用品牌强调琥珀——页内评分条 / 热力图 / 占比条
    /// 均以此为强调，光场与内容同色不打架。
    ///
    /// 注意：必须是 ScrollView 的同级底层而非其 `.background`——后者拿到的是
    /// 滚动内容尺寸的提案，内容不足一屏时光场会在半腰被硬切断（实测复现）。
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

    /// 页头：小标 + 标题 + 导语（规格与「库页」页头同轴：kicker tracking 3、标题 sectionTitle、同款上下边距）
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
        .padding(.bottom, 28)
    }

    /// 回顾正文：全宽概览 + 三行双栏交织——窄行类并排、宽图类成行，
    /// 概览全宽压阵，避免单列长龙的线性清单感
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            overviewRow
                .padding(.top, 24)
            HStack(alignment: .top, spacing: 36) {
                compositionSection
                statusSection
            }
            .padding(.top, Theme.sectionSpacing)
            HStack(alignment: .top, spacing: 36) {
                ratingSection
                creatorSection
            }
            .padding(.top, Theme.sectionSpacing)
            HStack(alignment: .top, spacing: 36) {
                trendSection
                heatmapSection
            }
            .padding(.top, Theme.sectionSpacing)
        }
        .padding(.bottom, 44)
    }

    /// 分节外壳：标题行（大标题 + EN 副标 + 可选注记）+ 内容；
    /// 节奏与「此刻」分节行同轴（sectionTitle、tracking 0.8、sectionSpacing）
    private func statSection<Content: View>(
        title: String,
        subtitle: String,
        note: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(Theme.sectionTitle)
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .tracking(0.8)
                    .foregroundStyle(Theme.ink3)
                Spacer()
                if let note {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.ink3)
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.sectionSpacing)
    }

    // MARK: - 馆藏构成

    private var compositionSection: some View {
        statSection(title: "馆藏构成", subtitle: "COMPOSITION", note: "\(store.items.count) 件馆藏") {
            VStack(spacing: 12) {
                ForEach(MediaType.allCases) { type in
                    compositionRow(type: type)
                }
                stackedBar
            }
        }
    }

    /// 类型占比行：色点 + 名称 + 数量 + 百分比
    private func compositionRow(type: MediaType) -> some View {
        let count = store.items.filter { $0.type == type }.count
        let fraction = store.items.isEmpty ? 0 : Double(count) / Double(store.items.count)
        return HStack(spacing: 10) {
            Circle().fill(typeColor(type)).frame(width: 8, height: 8)
            Text(type.rawValue)
                .font(Theme.body)
                .foregroundStyle(Theme.ink)
            Spacer()
            Text("\(count) 件")
                .font(Theme.body)
                .foregroundStyle(Theme.ink2)
            Text("\(Int(round(fraction * 100)))%")
                .font(Theme.control)
                .foregroundStyle(Theme.ink3)
                .frame(width: 38, alignment: .trailing)
        }
    }

    /// 三类代表色：影视蓝 / 音乐琥珀 / 书籍绿（Theme 类型色令牌）
    private func typeColor(_ type: MediaType) -> Color {
        switch type {
        case .movie: return Theme.typeMovie
        case .music: return Theme.typeMusic
        case .book:  return Theme.typeBook
        }
    }

    /// 占比横条：三段按类型占比铺满
    private var stackedBar: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(MediaType.allCases) { type in
                    let count = store.items.filter { $0.type == type }.count
                    let fraction = store.items.isEmpty ? 0 : Double(count) / Double(store.items.count)
                    Rectangle()
                        .fill(typeColor(type))
                        .frame(width: max(geo.size.width * fraction, 0))
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 8)
        .padding(.top, 4)
    }

    // MARK: - 状态分布

    private var statusSection: some View {
        statSection(title: "状态分布", subtitle: "STATUS") {
            VStack(spacing: 14) {
                ForEach(MediaStatus.allCases, id: \.self) { status in
                    statusRow(status: status)
                }
            }
        }
    }

    /// 状态行：徽标色点 + 名称 + 数量 + 占比条
    private func statusRow(status: MediaStatus) -> some View {
        let colors = Theme.statusColors(status)
        let count = store.items.filter { $0.status == status }.count
        let fraction = Double(count) / Double(store.items.count)
        return VStack(spacing: 6) {
            HStack(spacing: 10) {
                Circle().fill(colors.tx).frame(width: 8, height: 8)
                Text(statusName(status))
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(count) 件")
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink2)
            }
            ratioBar(fraction: fraction, color: colors.bg)
        }
    }

    private func statusName(_ status: MediaStatus) -> String {
        switch status {
        case .planned:    return "待品味"
        case .inProgress: return "进行中"
        case .completed:  return "已完成"
        }
    }

    // MARK: - 评分分布

    private var ratingSection: some View {
        statSection(title: "评分分布", subtitle: "RATING") {
            if ratedCount == 0 {
                Text("还没有评分记录")
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink3)
            } else {
                VStack(spacing: 14) {
                    ForEach(1...5, id: \.self) { stars in
                        ratingRow(stars: stars)
                    }
                }
            }
        }
    }

    /// 单星行：星数 + 琥珀占比条 + 数量（比例轴基为各星数量最大值）
    private func ratingRow(stars: Int) -> some View {
        let count = store.items.filter { $0.rating == stars }.count
        let fraction = Double(count) / Double(ratingMaxCount)
        return HStack(spacing: 10) {
            Text("\(stars) 星")
                .font(Theme.control)
                .foregroundStyle(Theme.ink2)
                .frame(width: 44, alignment: .leading)
            ratioBar(fraction: fraction, color: Theme.amber)
            Text("\(count)")
                .font(Theme.control)
                .foregroundStyle(Theme.ink3)
                .frame(width: 30, alignment: .trailing)
        }
    }

    // MARK: - 概览（全宽数据行）

    /// 六项大数字横排：与「此刻」数据条同构图（竖分隔线），不加壳直接铺在画布上；
    /// 原「概览」「品味足迹」两卡在此合流
    private var overviewRow: some View {
        HStack(spacing: 18) {
            overviewStat(label: "本月新增", value: "\(addedThisMonth)", unit: "件")
            overviewStat(label: "策展笔记", value: "\(noteCount)", unit: "条")
            overviewStat(
                label: "平均评分",
                value: averageRating.map { String(format: "%.1f", $0) } ?? "—",
                unit: averageRating == nil ? "" : "分"
            )
            overviewStat(
                label: "完成率",
                value: completionRate.map { "\($0)" } ?? "—",
                unit: completionRate == nil ? "" : "%"
            )
            overviewStat(label: "重温", value: "\(replayTotal)", unit: "次")
            overviewStat(
                label: "最常品味",
                value: mostTastedType?.rawValue ?? "—",
                accent: mostTastedType.map(typeColor)
            )
        }
    }

    /// 概览单项：大数字 + 单位 + 说明（accent 给「最常品味」类型色着色）
    private func overviewStat(label: String, value: String, unit: String = "", accent: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(accent ?? Theme.ink)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.ink3)
                }
            }
            Text(label)
                .font(.system(size: 11))
                .tracking(1)
                .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 收录热力图（近 12 周）

    private var heatmapSection: some View {
        let counts = heatmapCounts
        let total = counts.values.reduce(0, +)
        return statSection(title: "收录热力图", subtitle: "HEATMAP", note: "近 12 周") {
            VStack(spacing: 12) {
                // 格子随栏宽自适应放大（上限 28pt），12 周列组尽量铺满栏宽，
                // 与对栏的柱图在视觉重量上平衡
                GeometryReader { geo in
                    // 上限 28pt、下限 0：防御窄栏负值（当前窗口宽度下不可达，防未来布局改动）
                    let side = min(28, max(0, (geo.size.width - 11 * 3) / 12))
                    HStack(spacing: 3) {
                        ForEach(0..<12, id: \.self) { week in
                            VStack(spacing: 3) {
                                ForEach(0..<7, id: \.self) { weekday in
                                    heatmapCell(offset: week * 7 + weekday, counts: counts, side: side)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 7 * 28 + 6 * 3)
                HStack {
                    Text("近 12 周共收录 \(total) 件")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.ink3)
                    Spacer()
                    heatmapLegend
                }
            }
        }
    }

    /// 热力图单格：未来日期留空，其余按当日收录数四档着色（side 随栏宽自适应）
    private func heatmapCell(offset: Int, counts: [Int: Int], side: CGFloat) -> some View {
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: offset, to: heatmapStart)!
        let isFuture = date > cal.startOfDay(for: Date())
        let count = isFuture ? 0 : (counts[offset] ?? 0)
        return RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(isFuture ? Color.clear : heatColor(count))
            .frame(width: side, height: side)
            .help("\(date.formatted(.dateTime.month(.twoDigits).day(.twoDigits))) 收录 \(count) 件")
    }

    /// 着色档位：0 空格轨道色 / 1 件 35% / 2 件 65% / 3+ 件实心强调色
    private func heatColor(_ count: Int) -> Color {
        switch count {
        case 0:  return Theme.track
        case 1:  return Theme.amber.opacity(0.35)
        case 2:  return Theme.amber.opacity(0.65)
        default: return Theme.amber
        }
    }

    /// 图例：少 → 多 四档色阶
    private var heatmapLegend: some View {
        HStack(spacing: 4) {
            Text("少")
                .font(.system(size: 10))
                .foregroundStyle(Theme.ink3)
            ForEach([0, 1, 2, 3], id: \.self) { level in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(heatColor(level))
                    .frame(width: 10, height: 10)
            }
            Text("多")
                .font(.system(size: 10))
                .foregroundStyle(Theme.ink3)
        }
    }

    // MARK: - 月度收录趋势（近 6 个月）

    private var trendSection: some View {
        let months = monthlyTrend
        let maxCount = max(1, months.map(\.total).max() ?? 0)
        return statSection(title: "月度收录趋势", subtitle: "TREND", note: "近 6 个月") {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(months.enumerated()), id: \.offset) { _, month in
                    VStack(spacing: 6) {
                        Text("\(month.total)")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.ink3)
                        ZStack(alignment: .bottom) {
                            trendBar(month: month, maxCount: maxCount)
                        }
                        .frame(height: 96)
                        Text(month.label)
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.ink3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// 单月柱：按类型三段堆叠（影视蓝 / 音乐琥珀 / 书籍绿），空月为轨道色垫底
    private func trendBar(month: (label: String, total: Int, counts: [MediaType: Int]), maxCount: Int) -> some View {
        let barHeight = max(8, 96 * CGFloat(month.total) / CGFloat(maxCount))
        return Group {
            if month.total == 0 {
                Capsule().fill(Theme.track).frame(width: 22, height: 4)
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
                .frame(width: 22, height: barHeight)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 4, style: .continuous))
            }
        }
    }

    // MARK: - 创作者 TOP 榜

    private var creatorSection: some View {
        let creators = topCreators
        return statSection(title: "创作者 TOP 榜", subtitle: "TOP CREATORS") {
            if creators.isEmpty {
                Text("还没有创作者信息")
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink3)
            } else {
                VStack(spacing: 14) {
                    ForEach(Array(creators.enumerated()), id: \.offset) { index, creator in
                        creatorRow(rank: index + 1, creator: creator, maxCount: creators[0].count)
                    }
                }
            }
        }
    }

    /// 榜单行：名次 + 主导类型色点 + 名字 + 件数 + 占比条（轴基为榜首件数）
    private func creatorRow(rank: Int, creator: (name: String, count: Int, type: MediaType), maxCount: Int) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Text("\(rank)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(rank == 1 ? Theme.amber : Theme.ink3)
                    .frame(width: 16, alignment: .leading)
                Circle().fill(typeColor(creator.type)).frame(width: 8, height: 8)
                Text(creator.name)
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer()
                Text("\(creator.count) 件")
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink2)
            }
            ratioBar(fraction: Double(creator.count) / Double(maxCount), color: typeColor(creator.type))
        }
    }

    // MARK: - 通用

    /// 比例横条：轨道 + 按 fraction 填充
    private func ratioBar(fraction: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule().fill(color).frame(width: max(geo.size.width * fraction, 0))
            }
        }
        .frame(height: 6)
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