import SwiftUI

struct AddMediaView: View {

    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var selectedType: MediaType = .movie
    @State private var query: String = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    @State private var addedIds: Set<UUID> = []
    @State private var showingManualAdd = false
    @State private var manualTitle = ""
    @State private var manualLink = ""
    @State private var manualMetadata: LinkMetadata?
    @State private var isFetchingMetadata = false
    @State private var metadataFetchError = false

    /// 在途搜索任务与递增序号：新搜索/切换类型时取消旧任务，
    /// 回写前再比对序号兜底，防止晚返回的旧请求把结果写进错误的标签页
    @State private var searchTask: Task<Void, Never>?
    @State private var searchSequence = 0
    /// 链接元数据提取任务与序号（与搜索同款的竞态防护）
    @State private var metadataTask: Task<Void, Never>?
    @State private var metadataSequence = 0

    private let resultCoverWidth: CGFloat = 56

    var body: some View {
        VStack(spacing: 0) {
            header
            PaperRule()
            searchBar
            PaperRule()
            content
            PaperRule()
            footer
        }
        .background(ArtShelfStyle.paper)
        .frame(minWidth: 720, minHeight: 520)
    }

    // MARK: - 顶栏

    private var header: some View {
        HStack(spacing: 8) {
            Text("添加新收藏")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(ArtShelfStyle.ink)

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ArtShelfStyle.inkSecondary)
                    .frame(width: 24, height: 24)
                    .background(ArtShelfStyle.well, in: Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .help("关闭")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(ArtShelfStyle.surface)
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 12) {
            Picker("", selection: $selectedType) {
                ForEach(MediaType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 200)
            .onChange(of: selectedType) {
                // 切换类型：取消在途搜索并作废其回写，避免旧类型结果落入新标签页
                searchTask?.cancel()
                searchSequence += 1
                isSearching = false
                results = []
                addedIds = []
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ArtShelfStyle.inkTertiary)

                // 不在此处挂 onSubmit：Return 统一由右侧“搜索”按钮的
                // .keyboardShortcut(.return) 触发，避免一次回车发出两次请求
                TextField("搜索\(selectedType.rawValue)名称…", text: $query)
                    .textFieldStyle(.plain)
                    .font(ArtShelfStyle.body)

                if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(ArtShelfStyle.inkTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("清除")
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .wellBackground(radius: 7)

            Button("搜索") { performSearch() }
                .buttonStyle(.borderedProminent)
                .tint(ArtShelfStyle.accent)
                .controlSize(.regular)
                .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(ArtShelfStyle.surface)
    }

    // MARK: - 内容区

    @ViewBuilder
    private var content: some View {
        if isSearching {
            centered {
                ProgressView()
                    .controlSize(.small)
                Text("正在检索公开资料库…")
                    .font(.system(size: 13))
                    .foregroundStyle(ArtShelfStyle.inkSecondary)
            }
        } else if !results.isEmpty {
            resultsList
        } else if !query.isEmpty {
            centered {
                emptyGlyph("magnifyingglass")
                Text("未找到相关\(selectedType.rawValue)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ArtShelfStyle.ink)
                Text("尝试精简关键词，或在下方手动添加。")
                    .font(ArtShelfStyle.body)
                    .foregroundStyle(ArtShelfStyle.inkSecondary)
            }
        } else {
            centered {
                emptyGlyph(selectedType.systemImage)
                Text("搜索\(selectedType.rawValue)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ArtShelfStyle.ink)
                Text("输入关键词后点击搜索，自动拉取高清封面与元数据。")
                    .font(ArtShelfStyle.body)
                    .foregroundStyle(ArtShelfStyle.inkSecondary)
            }
        }
    }

    private func centered<C: View>(@ViewBuilder _ inner: () -> C) -> some View {
        VStack(spacing: 8) { inner() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyGlyph(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 32, weight: .light))
            .foregroundStyle(ArtShelfStyle.inkTertiary)
            .padding(.bottom, 4)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    if index > 0 {
                        PaperRule().padding(.leading, resultCoverWidth + 28)
                    }
                    resultRow(result)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
        }
    }

    private func resultRow(_ result: SearchResult) -> some View {
        ResultRow(
            result: result,
            coverWidth: resultCoverWidth,
            isAdded: addedIds.contains(result.id),
            onAdd: { addFromSearch(result) }
        )
    }

    // MARK: - 底栏

    private var footer: some View {
        HStack(spacing: 8) {
            if showingManualAdd {
                manualAddFields
            } else {
                Button {
                    showingManualAdd = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 11))
                        Text("手动录入 / 链接提取")
                    }
                    .font(ArtShelfStyle.control)
                    .foregroundStyle(ArtShelfStyle.inkSecondary)
                }
                .buttonStyle(.plain)
                .help("搜不到时可自己输入，或粘贴网页链接提取封面")

                Spacer()

                if !addedIds.isEmpty {
                    Text("已添加 \(addedIds.count) 项")
                        .font(ArtShelfStyle.cardMeta)
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                        .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(ArtShelfStyle.surface)
    }

    // MARK: - 手动添加区

    private var manualAddFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("标题")
                        .font(ArtShelfStyle.cardMeta)
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                    TextField("标题", text: $manualTitle)
                        .textFieldStyle(.plain)
                        .font(ArtShelfStyle.body)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .wellBackground(radius: 6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("链接")
                        .font(ArtShelfStyle.cardMeta)
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                    HStack(spacing: 6) {
                        TextField("粘贴网页链接，自动获取封面…", text: $manualLink)
                            .textFieldStyle(.plain)
                            .font(ArtShelfStyle.body)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .wellBackground(radius: 6)
                            .onSubmit { fetchManualMetadata() }

                        Button {
                            fetchManualMetadata()
                        } label: {
                            if isFetchingMetadata {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 44)
                            } else {
                                Text("提取")
                                    .frame(width: 44)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ArtShelfStyle.accent)
                        .controlSize(.small)
                        .disabled(isFetchingMetadata || manualLink.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(" ")
                        .font(ArtShelfStyle.cardMeta)
                    Button("添加") { addManual() }
                        .buttonStyle(.borderedProminent)
                        .tint(ArtShelfStyle.accent)
                        .controlSize(.small)
                        .disabled(manualTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(" ")
                        .font(ArtShelfStyle.cardMeta)
                    Button("取消") {
                        showingManualAdd = false
                        manualTitle = ""
                        manualLink = ""
                        manualMetadata = nil
                        metadataFetchError = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if let meta = manualMetadata {
                manualPreview(meta)
            } else if metadataFetchError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                        .foregroundStyle(ArtShelfStyle.inkSecondary)
                    Text("未能从链接获取信息，可直接输入标题后添加。")
                        .font(ArtShelfStyle.cardMeta)
                        .foregroundStyle(ArtShelfStyle.inkSecondary)
                }
            }
        }
    }

    private func manualPreview(_ meta: LinkMetadata) -> some View {
        HStack(spacing: 12) {
            CoverImageView(
                localPath: nil,
                remoteURL: meta.coverURL,
                aspectRatio: selectedType.coverAspectRatio,
                cornerRadius: 6
            )
            .frame(width: 44)
            .frame(height: 44 / selectedType.coverAspectRatio, alignment: .top)

            VStack(alignment: .leading, spacing: 3) {
                if let title = meta.title {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ArtShelfStyle.ink)
                        .lineLimit(1)
                }
                if let desc = meta.description {
                    Text(desc)
                        .font(ArtShelfStyle.cardMeta)
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if manualTitle.trimmingCharacters(in: .whitespaces).isEmpty,
               let title = meta.title {
                Button("使用此标题") {
                    manualTitle = title
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(8)
        .panelBackground(radius: 8)
    }

    // MARK: - 搜索

    private func performSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)

        // 取消上一次仍在途的搜索，并递增序号使其回写失效（取消 + 序号双保险）
        searchTask?.cancel()
        searchSequence += 1
        let sequence = searchSequence

        guard !q.isEmpty else {
            results = []
            isSearching = false
            return
        }

        // 快照当前类型，避免等待期间用户切换标签导致结果错位
        let type = selectedType
        isSearching = true
        searchTask = Task {
            let r = await MetadataService.shared.search(query: q, type: type)
            await MainActor.run {
                // 只接受最新一次搜索的回写，晚返回的旧请求直接丢弃
                guard sequence == searchSequence, !Task.isCancelled else { return }
                results = r
                isSearching = false
            }
        }
    }

    // MARK: - 添加逻辑

    private func addFromSearch(_ result: SearchResult) {
        var item = MediaItem(title: result.title, type: result.type)
        item.creator = result.creator
        item.year = result.year
        item.genre = result.genre
        item.synopsis = result.synopsis
        item.coverURL = result.coverURL
        item.webURL = result.webURL
        item.albumName = result.albumName
        item.appleMusicURL = result.appleMusicURL

        store.add(item)
        _ = withAnimation(.easeOut(duration: 0.16)) {
            addedIds.insert(result.id)
        }

        if let coverURL = result.coverURL {
            let itemId = item.id
            Task {
                if let localPath = await store.cacheCover(for: item, from: coverURL) {
                    await MainActor.run {
                        if var stored = store.item(for: itemId) {
                            stored.localCoverPath = localPath
                            store.update(stored)
                        }
                    }
                }
            }
        }
    }

    private func addManual() {
        let title = manualTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }

        var item = MediaItem(title: title, type: selectedType)
        item.webURL = manualLink.trimmingCharacters(in: .whitespaces).nilIfEmpty
        if let meta = manualMetadata {
            item.synopsis = meta.description
            item.coverURL = meta.coverURL
        }

        store.add(item)

        if let coverURL = item.coverURL {
            let itemId = item.id
            Task {
                if let localPath = await store.cacheCover(for: item, from: coverURL) {
                    await MainActor.run {
                        if var stored = store.item(for: itemId) {
                            stored.localCoverPath = localPath
                            store.update(stored)
                        }
                    }
                }
            }
        }

        manualTitle = ""
        manualLink = ""
        manualMetadata = nil
        metadataFetchError = false
        showingManualAdd = false
    }

    private func fetchManualMetadata() {
        let link = manualLink.trimmingCharacters(in: .whitespaces)
        guard !link.isEmpty else { return }

        // 取消上一次提取并递增序号，旧请求晚返回时直接丢弃
        metadataTask?.cancel()
        metadataSequence += 1
        let sequence = metadataSequence

        isFetchingMetadata = true
        metadataFetchError = false
        metadataTask = Task {
            let meta = await LinkMetadataService.shared.fetch(from: link)
            await MainActor.run {
                guard sequence == metadataSequence, !Task.isCancelled else { return }
                isFetchingMetadata = false
                if let meta {
                    manualMetadata = meta
                    metadataFetchError = false
                } else {
                    manualMetadata = nil
                    metadataFetchError = true
                }
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

// MARK: - 单条搜索结果

private struct ResultRow: View {

    let result: SearchResult
    let coverWidth: CGFloat
    let isAdded: Bool
    let onAdd: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            CoverImageView(
                localPath: nil,
                remoteURL: result.coverURL,
                aspectRatio: result.type.coverAspectRatio,
                cornerRadius: 6
            )
            .frame(width: coverWidth)
            .frame(height: coverWidth / result.type.coverAspectRatio, alignment: .top)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(ArtShelfStyle.ink)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let creator = result.creator, !creator.isEmpty {
                        Text(creator).lineLimit(1)
                    }
                    if let year = result.year {
                        Text(String(year)).monospacedDigit()
                    }
                }
                .font(ArtShelfStyle.cardMeta)
                .foregroundStyle(ArtShelfStyle.inkSecondary)

                if let synopsis = result.synopsis, !synopsis.isEmpty {
                    Text(synopsis)
                        .font(ArtShelfStyle.cardMeta)
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                        .lineLimit(2)
                        .lineSpacing(2)
                        .padding(.top, 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            addButton
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered && !isAdded ? ArtShelfStyle.hoverFill : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) { isHovered = hovering }
        }
    }

    @ViewBuilder
    private var addButton: some View {
        if isAdded {
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                Text("已添加")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(ArtShelfStyle.inkTertiary)
            .frame(width: 72, height: 26)
        } else {
            Button("添加", action: onAdd)
                .buttonStyle(.borderedProminent)
                .tint(ArtShelfStyle.accent)
                .controlSize(.small)
                .frame(width: 72)
        }
    }
}
