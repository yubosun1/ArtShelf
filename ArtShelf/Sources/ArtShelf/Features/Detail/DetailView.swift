import SwiftUI

/// 沉浸整版详情页（设计稿见 docs/product-design.md §4.3）
///
/// 左侧大封面 + 主色光晕；右侧自上而下：标题 / 元信息 / 标签、
/// 状态与流转操作、评分、进度、策展手记、关联文件与链接、时间底注。
/// 藏品按 id 从 `LibraryStore` 实时取用（值类型快照），修改一律经由
/// store 方法 / `store.update`，保证流转副作用（§6）一致。
struct DetailView: View {

    /// 藏品 id；展示期间随时可被删除，删除后落到占位页
    let itemID: UUID

    @Environment(AppState.self) private var appState
    @Environment(LibraryStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    @State private var glowColor: Color?
    @State private var tagText = ""
    @State private var totalInput = ""
    @State private var noteText = ""

    /// 当前藏品快照；被删除时为 nil（显示占位）
    private var item: MediaItem? { store.item(for: itemID) }

    var body: some View {
        Group {
            if let item {
                content(item)
            } else {
                deletedPlaceholder
            }
        }
        .background(Theme.bg)
        .task(id: itemID) { syncLocals() }
    }

    // MARK: - 内容（藏品存在时）

    private func content(_ item: MediaItem) -> some View {
        VStack(spacing: 0) {
            backRow
            HStack(alignment: .top, spacing: 44) {
                coverColumn(item)
                ScrollView {
                    rightColumn(item)
                }
            }
        }
        .padding(.horizontal, Theme.contentPadding)
        .padding(.top, 28)
        .padding(.bottom, Theme.contentPadding)
    }

    // MARK: - 已删除占位

    private var deletedPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "trash")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.ink3)
            Text("该藏品已删除")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.ink)
            Button {
                appState.closeDetail()
            } label: {
                Text("返回")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.amberOn)
                    .padding(.horizontal, 20)
                    .frame(height: 34)
                    .background(Theme.amberBtn)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 顶部返回

    private var backRow: some View {
        HStack {
            Button {
                appState.closeDetail()
            } label: {
                Label("返回", systemImage: "chevron.left")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.ink2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.well)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Theme.rule, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("关闭详情（Esc）")
            Spacer()
        }
        .padding(.bottom, 26)
    }

    // MARK: - 左栏：大封面 + 主色光晕

    private func coverColumn(_ item: MediaItem) -> some View {
        CoverImageView(item: item) { glowColor = $0 }
            .frame(width: 300, height: 300 / item.type.coverAspectRatio)
            .coverGlow(glowColor, scheme: scheme)
            .padding(.top, 2)
    }

    // MARK: - 右栏内容（最大宽度 560）

    private func rightColumn(_ item: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 30) {
            titleBlock(item)
            statusRow(item)
            ratingBlock(item)
            progressBlock(item)
            notesBlock(item)
            relatedBlock(item)
            footerText(item)
        }
        .frame(maxWidth: 560, alignment: .leading)
        .padding(.bottom, 12)
    }

    // MARK: - 标题 / 元信息 / 标签

    private func titleBlock(_ item: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.title)
                .font(.system(size: 32, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(metaLine(item))
                .font(Theme.body)
                .foregroundStyle(Theme.ink2)
            tagEditor(item)
                .padding(.top, 6)
        }
    }

    private func metaLine(_ item: MediaItem) -> String {
        [item.creator, item.year.map(String.init), item.type.rawValue]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// 标签编辑：逗号分隔的输入框，提交时解析回 `item.tags`
    private func tagEditor(_ item: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("标签，用逗号分隔", text: $tagText)
                .textFieldStyle(.plain)
                .font(Theme.body)
                .foregroundStyle(Theme.ink)
                .onSubmit { commitTags(item) }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.well)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Theme.rule, lineWidth: 1)
                )
            if !item.tags.isEmpty {
                HStack(spacing: 8) {
                    ForEach(item.tags, id: \.self) { tag in
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
        }
    }

    private func commitTags(_ item: MediaItem) {
        // 支持中文 / 英文逗号，去空白、去重
        var seen = Set<String>()
        let parsed = tagText
            .split(whereSeparator: { $0 == "，" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        var copy = item
        copy.tags = parsed
        store.update(copy)
        tagText = parsed.joined(separator: "，")
    }

    // MARK: - 状态行：徽标 + 流转操作

    private func statusRow(_ item: MediaItem) -> some View {
        HStack(spacing: 12) {
            StatusBadge(status: item.status, type: item.type, text: badgeText(item))
            if item.replayCount > 0 {
                Text("第 \(item.replayCount + 1) 次重温")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
            Spacer()
            statusAction(item)
        }
    }

    /// 进行中时徽标附带进度百分比（如「在看 62%」）
    private func badgeText(_ item: MediaItem) -> String? {
        if item.status == .inProgress, item.progressTotal > 0 {
            return "\(item.statusLabel) \(Int(item.progress * 100))%"
        }
        return nil
    }

    @ViewBuilder
    private func statusAction(_ item: MediaItem) -> some View {
        switch item.status {
        case .planned:
            primaryButton("开始品味", systemImage: "play.fill") {
                store.startTasting(item)
            }
        case .inProgress:
            ghostButton("标记\(item.type.completedLabel)", systemImage: "checkmark") {
                store.finish(item)
            }
        case .completed:
            ghostButton("再看一遍", systemImage: "arrow.counterclockwise") {
                store.replay(item)
            }
        }
    }

    // MARK: - 评分

    private func ratingBlock(_ item: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("评分")
            RatingStars(rating: item.rating, size: 17) { newValue in
                // 值类型快照：改字段后整体替换
                var copy = item
                copy.rating = newValue
                store.update(copy)
            }
        }
    }

    // MARK: - 进度：滑杆 + 步进 + 总量 + 标记看完

    private func progressBlock(_ item: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("进度")
            if item.progressTotal > 0 {
                progressSliderRow(item)
                Text("\(item.progressText) · \(Int(item.progress * 100))%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.amber)
            } else {
                Text("记录总\(item.type.progressUnit)数后开启进度")
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink3)
            }
            totalRow(item)
        }
    }

    private func progressSliderRow(_ item: MediaItem) -> some View {
        HStack(spacing: 10) {
            stepButton(item, -1)
            Slider(value: progressBinding(item), in: 0...Double(max(item.progressTotal, 1)), step: 1)
                .tint(Theme.amberBtn)
            stepButton(item, 1)
        }
    }

    /// 滑杆双向绑定：拖动即写入进度（副作用收口在 `store.updateProgress`）
    private func progressBinding(_ item: MediaItem) -> Binding<Double> {
        Binding(
            get: { Double(item.progressCurrent) },
            set: { store.updateProgress(item, current: Int($0.rounded())) }
        )
    }

    private func stepButton(_ item: MediaItem, _ sign: Int) -> some View {
        let step = sign * item.type.progressStep
        return Button {
            store.updateProgress(item, current: item.progressCurrent + step)
        } label: {
            Text("\(step > 0 ? "+" : "")\(step) \(item.type.progressUnit)")
                .font(Theme.control)
                .foregroundStyle(Theme.ink2)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.well)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Theme.rule, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func totalRow(_ item: MediaItem) -> some View {
        HStack(spacing: 10) {
            Text("总量")
                .font(Theme.body)
                .foregroundStyle(Theme.ink2)
            TextField("数字", text: $totalInput)
                .textFieldStyle(.plain)
                .font(Theme.body)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.well)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.rule, lineWidth: 1)
                )
                .onSubmit { commitTotal(item) }
            Text(item.type.progressUnit)
                .font(Theme.body)
                .foregroundStyle(Theme.ink2)
            Spacer()
            ghostButton("标记看完", systemImage: "checkmark.circle") {
                store.updateProgress(item, current: item.progressTotal)
            }
            .disabled(item.progressTotal <= 0)
            .opacity(item.progressTotal <= 0 ? 0.4 : 1)
        }
    }

    private func commitTotal(_ item: MediaItem) {
        let trimmed = totalInput.trimmingCharacters(in: .whitespaces)
        if let value = Int(trimmed), value > 0 {
            totalInput = "\(value)"
            store.updateProgress(item, current: item.progressCurrent, total: value)
        } else {
            // 非法输入回退显示当前总量
            totalInput = item.progressTotal > 0 ? "\(item.progressTotal)" : ""
        }
    }

    // MARK: - 策展手记

    private func notesBlock(_ item: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("策展手记")
            noteEditor(item)
            if item.sortedNotes.isEmpty {
                Text("还没有手记，记下第一笔吧。")
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink3)
            } else {
                ForEach(item.sortedNotes) { note in
                    noteCard(item, note)
                }
            }
        }
    }

    private func noteEditor(_ item: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                if noteText.isEmpty {
                    Text("记下此刻的感受…")
                        .font(Theme.body)
                        .foregroundStyle(Theme.ink3)
                        .padding(.top, 11)
                        .padding(.leading, 13)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $noteText)
                    .font(Theme.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 66)
                    .background(Theme.well)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Theme.rule, lineWidth: 1)
                    )
            }
            HStack {
                Spacer()
                Button("记下") { commitNote(item) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                    .opacity(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 1)
            }
        }
    }

    private func commitNote(_ item: MediaItem) {
        let text = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.addNote(item, text: text)
        noteText = ""
    }

    private func noteCard(_ item: MediaItem, _ note: NoteEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.ink3)
                Text(note.text)
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 10)
            Button {
                store.deleteNote(item, noteID: note.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.ink3)
            }
            .buttonStyle(.plain)
            .help("删除这条手记")
        }
        .padding(14)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: Theme.panelCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.panelCorner, style: .continuous)
                .strokeBorder(Theme.rule, lineWidth: 1)
        )
    }

    // MARK: - 关联文件与链接（双击打开）

    private func relatedBlock(_ item: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("关联")
            localFileRow(item)
            if let url = item.webURL {
                urlRow(systemImage: "globe", url: url)
            }
            if let url = item.appleMusicURL {
                urlRow(systemImage: "music.note", url: url)
            }
        }
    }

    private func localFileRow(_ item: MediaItem) -> some View {
        let exists = FileService.shared.localFileExists(at: item.localFilePath)
        return HStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink3)
                .frame(width: 20)
            Group {
                if let path = item.localFilePath {
                    Text(path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(exists ? Theme.ink : Theme.ink3)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            if exists { FileService.shared.openLocalFile(at: path) }
                        }
                    if !exists {
                        Text("（文件不存在）")
                            .foregroundStyle(Theme.ink3)
                    }
                } else {
                    Text("未关联本地文件")
                        .foregroundStyle(Theme.ink3)
                }
            }
            .font(Theme.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            if let path = item.localFilePath, exists {
                Text("双击打开")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.ink3)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { FileService.shared.openLocalFile(at: path) }
            }
            Button("选取文件…") { pickLocalFile(item) }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Theme.ink2)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Theme.well)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Theme.rule, lineWidth: 1))
        }
        .padding(12)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: Theme.panelCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.panelCorner, style: .continuous)
                .strokeBorder(Theme.rule, lineWidth: 1)
        )
    }

    private func urlRow(systemImage: String, url: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink3)
                .frame(width: 20)
            Text(url)
                .font(Theme.body)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { FileService.shared.openURL(url) }
            Text("双击打开")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.ink3)
        }
        .padding(12)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: Theme.panelCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.panelCorner, style: .continuous)
                .strokeBorder(Theme.rule, lineWidth: 1)
        )
    }

    private func pickLocalFile(_ item: MediaItem) {
        guard let path = FileService.shared.pickFile(allowedTypes: ["public.item"]) else { return }
        var copy = item
        copy.localFilePath = path
        store.update(copy)
    }

    // MARK: - 底部时间底注

    private func footerText(_ item: MediaItem) -> some View {
        var parts = ["添加于 \(item.dateAdded.formatted(date: .long, time: .shortened))"]
        if let last = item.lastViewedDate {
            parts.append("最近浏览 \(last.formatted(date: .long, time: .shortened))")
        }
        return Text(parts.joined(separator: " / "))
            .font(.system(size: 11))
            .foregroundStyle(Theme.ink3)
    }

    // MARK: - 本地状态同步

    /// 详情打开或切换藏品时，把 store 快照写回编辑态（标签 / 总量输入框）
    private func syncLocals() {
        guard let item else { return }
        tagText = item.tags.joined(separator: "，")
        totalInput = item.progressTotal > 0 ? "\(item.progressTotal)" : ""
    }

    // MARK: - 通用小件

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.sectionTitle)
            .foregroundStyle(Theme.ink)
    }

    /// 琥珀色主按钮
    private func primaryButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(Theme.amberOn)
                .padding(.horizontal, 18)
                .frame(height: 34)
                .background(Theme.amberBtn)
                .clipShape(Capsule())
                .shadow(color: Theme.amberBtn.opacity(0.32), radius: 11, y: 8)
        }
        .buttonStyle(.plain)
    }

    /// 描边幽灵按钮
    private func ghostButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 16)
                .frame(height: 34)
                .background(Theme.well)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Theme.rule, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}