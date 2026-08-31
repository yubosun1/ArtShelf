import SwiftUI

/// 「此刻」首页：Hero（正在品味）+ 进行中队列 + 三类精选 + 数据条
struct NowView: View {

    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var store

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
                    NowHeroView(item: hero, queue: Array(inProgress.dropFirst()))
                } else {
                    emptyHero
                }

                ForEach(MediaType.allCases) { type in
                    MediaSectionRow(
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
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.rule).frame(height: 1)
        }
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
                        if let type = items.first?.type, let tab = AppTab.allCases.first(where: { $0.mediaType == type }) {
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
                    .padding(.vertical, 4)
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

    private var addedThisMonth: Int {
        let cal = Calendar.current
        return items.filter { cal.isDate($0.dateAdded, equalTo: Date(), toGranularity: .month) }.count
    }

    private var noteCount: Int { items.reduce(0) { $0 + $1.notes.count } }

    private var averageRating: Double? {
        let rated = items.filter { $0.rating > 0 }
        guard !rated.isEmpty else { return nil }
        return Double(rated.reduce(0) { $0 + $1.rating }) / Double(rated.count)
    }

    var body: some View {
        HStack(spacing: 0) {
            stat(value: "\(items.count)", unit: "件", label: "馆藏总量")
            divider
            stat(value: "\(inProgressCount)", unit: "件", label: "此刻进行中")
            divider
            stat(value: "\(addedThisMonth)", unit: "件", label: "本月新增")
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

    private func stat(value: String, unit: String, label: String) -> some View {
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
        .padding(.horizontal, 22)
    }

    private var divider: some View {
        Rectangle().fill(Theme.rule).frame(width: 1, height: 40)
    }
}
