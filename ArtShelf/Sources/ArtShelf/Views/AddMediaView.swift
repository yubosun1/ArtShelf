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

    /// 搜索结果里封面的固定宽度——高度由宽高比推出，与图片原始尺寸无关。
    private let resultCoverWidth: CGFloat = 58

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
            Text("添加收藏")
                .font(ArtShelfStyle.title(14))
                .foregroundStyle(ArtShelfStyle.ink)

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ArtShelfStyle.inkSecondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .help("关闭")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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
            .frame(width: 210)
            .onChange(of: selectedType) {
                results = []
                addedIds = []
            }

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ArtShelfStyle.inkTertiary)

                TextField("搜索\(selectedType.rawValue)…", text: $query)
                    .textFieldStyle(.plain)
                    .font(ArtShelfStyle.body)
                    .onSubmit { performSearch() }

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
            .frame(height: 27)
            .wellBackground()

            Button("搜索") { performSearch() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 11)
        .background(ArtShelfStyle.surface)
    }

    // MARK: - 内容区

    @ViewBuilder
    private var content: some View {
        if isSearching {
            centered {
                ProgressView()
                    .controlSize(.small)
                Text("正在搜索…")
                    .font(ArtShelfStyle.body)
                    .foregroundStyle(ArtShelfStyle.inkSecondary)
            }
        } else if !results.isEmpty {
            resultsList
        } else if !query.isEmpty {
            centered {
                emptyGlyph("magnifyingglass")
                Text("没有找到结果")
                    .font(ArtShelfStyle.title(14))
                    .foregroundStyle(ArtShelfStyle.ink)
                Text("换个说法，或者手动添加。")
                    .font(ArtShelfStyle.body)
                    .foregroundStyle(ArtShelfStyle.inkSecondary)
            }
        } else {
            centered {
                emptyGlyph(selectedType.systemImage)
                Text("搜索\(selectedType.rawValue)")
                    .font(ArtShelfStyle.title(14))
                    .foregroundStyle(ArtShelfStyle.ink)
                Text("输入名称后按回车。")
                    .font(ArtShelfStyle.body)
                    .foregroundStyle(ArtShelfStyle.inkSecondary)
            }
        }
    }

    private func centered<C: View>(@ViewBuilder _ inner: () -> C) -> some View {
        VStack(spacing: 7) { inner() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyGlyph(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 26, weight: .light))
            .foregroundStyle(ArtShelfStyle.inkTertiary)
            .padding(.bottom, 4)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    if index > 0 {
                        PaperRule().padding(.leading, resultCoverWidth + 34)
                    }
                    resultRow(result)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
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
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 10.5))
                        Text("手动添加")
                    }
                    .font(ArtShelfStyle.control)
                    .foregroundStyle(ArtShelfStyle.inkSecondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("搜不到时自己填一条，或粘贴链接自动获取封面")

                Spacer()

                if !addedIds.isEmpty {
                    Text("已添加 \(addedIds.count) 项")
                        .font(ArtShelfStyle.cardMeta)
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                        .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 11)
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
                        .frame(height: 26)
                        .wellBackground()
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
                            .frame(height: 26)
                            .wellBackground()
                            .onSubmit { fetchManualMetadata() }

                        Button {
                            fetchManualMetadata()
                        } label: {
                            if isFetchingMetadata {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 44)
                            } else {
                                Text("获取")
                                    .frame(width: 44)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isFetchingMetadata || manualLink.trimmingCharacters(in: .whitespaces).isEmpty)
                        .help("从链接自动获取标题与封面")
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(" ")
                        .font(ArtShelfStyle.cardMeta)
                    Button("添加") { addManual() }
                        .buttonStyle(.borderedProminent)
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
                    .buttonStyle(.plain)
                    .font(ArtShelfStyle.control)
                    .foregroundStyle(ArtShelfStyle.inkSecondary)
                }
            }

            if let meta = manualMetadata {
                manualPreview(meta)
            } else if metadataFetchError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                        .foregroundStyle(ArtShelfStyle.inkSecondary)
                    Text("未能从链接获取信息，可手动填写标题后添加。")
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
                cornerRadius: 4
            )
            .frame(width: 44)
            .frame(height: 44 / selectedType.coverAspectRatio, alignment: .top)

            VStack(alignment: .leading, spacing: 3) {
                if let title = meta.title {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ArtShelfStyle.ink)
                        .lineLimit(1)
                }
                if let desc = meta.description {
                    Text(desc)
                        .font(ArtShelfStyle.cardMeta)
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                        .lineLimit(2)
                        .lineSpacing(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if manualTitle.trimmingCharacters(in: .whitespaces).isEmpty,
               let title = meta.title {
                Button("使用此标题") {
                    manualTitle = title
                }
                .buttonStyle(.plain)
                .font(ArtShelfStyle.control)
                .foregroundStyle(ArtShelfStyle.accent)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: ArtShelfStyle.controlRadius, style: .continuous)
                .fill(ArtShelfStyle.well.opacity(0.6))
        )
    }

    // MARK: - 搜索

    private func performSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; return }

        isSearching = true
        Task {
            let r = await MetadataService.shared.search(query: q, type: selectedType)
            await MainActor.run {
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
        item.synopsis = result.synopsis
        item.coverURL = result.coverURL
        item.webURL = result.webURL
        item.albumName = result.albumName
        item.appleMusicURL = result.appleMusicURL

        store.add(item)
        _ = withAnimation(.easeOut(duration: 0.16)) {
            addedIds.insert(result.id)
        }

        // 异步下载封面到本地缓存
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

        // 异步下载封面到本地缓存
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

    /// 从链接自动获取标题 / 封面 / 简介
    private func fetchManualMetadata() {
        let link = manualLink.trimmingCharacters(in: .whitespaces)
        guard !link.isEmpty else { return }

        isFetchingMetadata = true
        metadataFetchError = false
        Task {
            let meta = await LinkMetadataService.shared.fetch(from: link)
            await MainActor.run {
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

// MARK: - 工具

private extension String {
    /// 空字符串转 nil，方便写入可选字段
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
            // 固定宽度 + 固定高度的封面槽：任何尺寸的远程图都只在槽内裁切，
            // 不会把这一行撑高去盖住相邻内容。
            CoverImageView(
                localPath: nil,
                remoteURL: result.coverURL,
                aspectRatio: result.type.coverAspectRatio,
                cornerRadius: 4
            )
            .frame(width: coverWidth)
            .frame(height: coverWidth / result.type.coverAspectRatio, alignment: .top)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.system(size: 13, weight: .medium))
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
                .font(.system(size: 10.5))
                .foregroundStyle(ArtShelfStyle.inkSecondary)

                if let synopsis = result.synopsis, !synopsis.isEmpty {
                    Text(synopsis)
                        .font(.system(size: 10.5))
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                        .lineLimit(2)
                        .lineSpacing(2)
                        .padding(.top, 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            addButton
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: ArtShelfStyle.controlRadius, style: .continuous)
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
            .font(ArtShelfStyle.control)
            .foregroundStyle(ArtShelfStyle.inkTertiary)
            .frame(width: 68, height: 25)
        } else {
            Button("添加", action: onAdd)
                .buttonStyle(.borderedProminent)
                .frame(width: 68)
        }
    }
}
