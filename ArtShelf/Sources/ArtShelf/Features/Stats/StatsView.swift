import SwiftUI

/// 「统计」页：馆藏构成 / 状态分布 / 评分分布 / 概览
///
/// 口径约束（见 docs/product-design.md §4.5）：所有指标一律从现有字段
/// 直接派生，不做「品味时长」类指标。
struct StatsView: View {

    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var store

    // MARK: - 派生统计

    /// 本月新增件数（与「此刻」数据条同口径）
    private var addedThisMonth: Int {
        let cal = Calendar.current
        return store.items.filter { cal.isDate($0.dateAdded, equalTo: Date(), toGranularity: .month) }.count
    }

    /// 策展笔记总数
    private var noteCount: Int { store.items.reduce(0) { $0 + $1.notes.count } }

    /// 平均评分（仅统计已评分条目，即 rating > 0）
    private var averageRating: Double? {
        let rated = store.items.filter { $0.rating > 0 }
        guard !rated.isEmpty else { return nil }
        return Double(rated.reduce(0) { $0 + $1.rating }) / Double(rated.count)
    }

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

    // MARK: - 页面

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if store.items.isEmpty {
                    emptyState
                } else {
                    cardGrid.padding(.top, 28)
                }
            }
            .padding(.horizontal, Theme.contentPadding)
        }
        .scrollIndicators(.hidden)
    }

    /// 页头：小标 + 标题 + 导语
    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("STATS")
                .font(Theme.kicker)
                .tracking(2)
                .foregroundStyle(Theme.ink3)
            Text("统计")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("你的品味数据全部来自本地馆藏，一目了然。")
                .font(Theme.body)
                .foregroundStyle(Theme.ink2)
        }
        .padding(.top, 24)
        .padding(.bottom, Theme.sectionSpacing)
    }

    /// 四张统计卡片（自适应 2–3 列网格）
    private var cardGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 300), spacing: 20)],
            alignment: .leading,
            spacing: 20
        ) {
            compositionCard
            statusCard
            ratingCard
            overviewCard
        }
        .padding(.bottom, 40)
    }

    /// 卡片外壳：面板底色 + 发丝描边 + 14 圆角
    private func statCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(Theme.sectionTitle)
                .foregroundStyle(Theme.ink)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.rule, lineWidth: 1)
        )
    }

    // MARK: - 馆藏构成

    private var compositionCard: some View {
        statCard(title: "馆藏构成") {
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

    private var statusCard: some View {
        statCard(title: "状态分布") {
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

    private var ratingCard: some View {
        statCard(title: "评分分布") {
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

    // MARK: - 概览（本月新增 / 笔记 / 平均评分）

    private var overviewCard: some View {
        statCard(title: "概览") {
            HStack(spacing: 18) {
                overviewStat(value: "\(addedThisMonth)", unit: "件", label: "本月新增")
                divider
                overviewStat(value: "\(noteCount)", unit: "条", label: "策展笔记")
                divider
                overviewStat(
                    value: averageRating.map { String(format: "%.1f", $0) } ?? "—",
                    unit: averageRating == nil ? "" : "分",
                    label: "平均评分"
                )
            }
        }
    }

    /// 概览单项：大数字 + 单位 + 说明
    private func overviewStat(value: String, unit: String, label: String) -> some View {
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
            }
            Text(label)
                .font(.system(size: 11))
                .tracking(1)
                .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle().fill(Theme.rule).frame(width: 1, height: 40)
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