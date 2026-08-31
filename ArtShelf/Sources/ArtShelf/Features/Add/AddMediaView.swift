import SwiftUI
import UniformTypeIdentifiers

// MARK: - 收录新媒体弹窗

/// 收录新媒体弹窗（由 v2 的 AddMediaView 移植，界面改用 v3 设计令牌）
///
/// 流程：类型选择 → 关键词搜索 → 结果列表「选用」预填表单 → 补充信息后确认收录；
/// 搜不到时可手动录入（支持粘贴链接提取标题 / 简介 / 封面）；
/// 书籍额外支持选取 / 拖入 EPUB 提取封面；三类都可关联本地文件与在线链接。
@MainActor
struct AddMediaView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(LibraryStore.self) private var store

    // MARK: - 类型与搜索

    @State private var selectedType: MediaType = .movie
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false

    /// 在途搜索任务与递增序号：新搜索 / 切换类型时取消旧任务，
    /// 回写前再比对序号兜底，防止晚返回的旧请求把结果写进错误的类型页
    @State private var searchTask: Task<Void, Never>?
    @State private var searchSequence = 0

    @FocusState private var queryFocused: Bool

    // MARK: - 编辑表单（选用搜索结果或手动录入后进入）

    @State private var isEditing = false
    @State private var selectedResultID: UUID?
    @State private var draft = EntryDraft()
    @State private var coverPreview: NSImage?

    /// 链接元数据提取任务与序号（与搜索同款竞态防护）
    @State private var metadataTask: Task<Void, Never>?
    @State private var metadataSequence = 0
    @State private var isFetchingMetadata = false
    @State private var metadataError = false

    /// EPUB 封面提取任务与状态
    @State private var epubTask: Task<Void, Never>?
    @State private var isExtractingCover = false
    @State private var coverMessage: String?
    @State private var isEPUBDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.rule).frame(height: 1)

            if isEditing {
                editForm
            } else {
                searchBar
                Rectangle().fill(Theme.rule).frame(height: 1)
                browseContent
            }

            Rectangle().fill(Theme.rule).frame(height: 1)
            footer
        }
        .background(Theme.bg)
        .frame(width: 560, height: 640)
        .onDisappear {
            searchTask?.cancel()
            metadataTask?.cancel()
            epubTask?.cancel()
        }
    }

    // MARK: - 顶栏

    private var header: some View {
        HStack(spacing: 8) {
            Text("添加新收藏")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.ink)

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.ink2)
                    .frame(width: 24, height: 24)
                    .background(Theme.well, in: Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .help("关闭")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
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
                selectedResultID = nil
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.ink3)

                // 不在此处挂 onSubmit：Return 统一由右侧「搜索」按钮的
                // .keyboardShortcut(.return) 触发，避免一次回车发出两次请求
                TextField("搜索\(selectedType.rawValue)名称…", text: $query)
                    .textFieldStyle(.plain)
                    .font(Theme.body)
                    .focused($queryFocused)

                if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.ink3)
                    }
                    .buttonStyle(.plain)
                    .help("清除")
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Theme.well)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(queryFocused ? Theme.amber.opacity(0.5) : Theme.rule, lineWidth: 1)
            )

            primaryButton("搜索") { performSearch() }
                .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .onAppear { queryFocused = true }
    }

    // MARK: - 浏览内容区（搜索中 / 结果列表 / 空态）

    private var browseContent: some View {
        Group {
            if isSearching {
                centered {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在检索公开资料库…")
                        .font(Theme.body)
                        .foregroundStyle(Theme.ink2)
                }
            } else if !results.isEmpty {
                resultsList
            } else if !query.isEmpty {
                centered {
                    emptyGlyph("magnifyingglass")
                    Text("未找到相关\(selectedType.rawValue)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("试试精简关键词，或使用底部的手动录入。")
                        .font(Theme.body)
                        .foregroundStyle(Theme.ink2)
                }
            } else {
                centered {
                    emptyGlyph(selectedType.systemImage)
                    Text("搜索\(selectedType.rawValue)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("输入关键词检索公开资料库，自动拉取高清封面与元数据。")
                        .font(Theme.body)
                        .foregroundStyle(Theme.ink2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func centered<C: View>(@ViewBuilder _ inner: () -> C) -> some View {
        VStack(spacing: 8) { inner() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyGlyph(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 32, weight: .light))
            .foregroundStyle(Theme.ink3)
            .padding(.bottom, 4)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    if index > 0 {
                        Rectangle().fill(Theme.rule).frame(height: 1).padding(.leading, 84)
                    }
                    ResultRow(result: result, isSelected: selectedResultID == result.id) {
                        choose(result)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 编辑表单

    private var editForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("基本信息")

                fieldBox {
                    TextField("标题（必填）", text: $draft.title)
                }

                HStack(spacing: 12) {
                    fieldBox {
                        TextField("创作者（导演 / 艺术家 / 作者）", text: $draft.creator)
                    }
                    .frame(maxWidth: .infinity)

                    fieldBox {
                        TextField("年份", text: $draft.year)
                    }
                    .frame(width: 100)
                }

                if selectedType == .music {
                    HStack(spacing: 12) {
                        fieldBox {
                            TextField("专辑名", text: $draft.albumName)
                        }
                        .frame(maxWidth: .infinity)

                        fieldBox {
                            TextField("流派 / 风格", text: $draft.genre)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    fieldBox {
                        TextField(selectedType == .movie ? "类型 / 流派（如：剧情 · 悬疑）" : "类别 / 流派", text: $draft.genre)
                    }
                }

                ZStack(alignment: .topLeading) {
                    if draft.synopsis.isEmpty {
                        Text("简介（可选）")
                            .font(Theme.body)
                            .foregroundStyle(Theme.ink3.opacity(0.6))
                            .padding(.top, 10)
                            .padding(.leading, 12)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $draft.synopsis)
                        .font(Theme.body)
                        .foregroundStyle(Theme.ink)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .frame(height: 64)
                        .background(Theme.well)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }

                ruleDivider

                sectionLabel("封面")

                HStack(spacing: 8) {
                    fieldBox {
                        TextField("封面图片链接（远程）", text: $draft.coverURL)
                    }
                    secondaryButton("手选图片…") { pickCoverImage() }
                }

                if let preview = coverPreview {
                    HStack(spacing: 10) {
                        Image(nsImage: preview)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: selectedType == .music ? 44 : 66)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("本地封面已就位")
                                .font(Theme.cardMeta)
                                .foregroundStyle(Theme.ink2)
                            Text(draft.localCoverPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "")
                                .font(Theme.cardMeta)
                                .foregroundStyle(Theme.ink3)
                                .lineLimit(1)
                        }
                        Spacer()
                        secondaryButton("移除") {
                            draft.localCoverPath = nil
                            coverPreview = nil
                            coverMessage = nil
                        }
                    }
                }

                // 仅书籍支持从 EPUB 提取封面（选取或拖入）
                if selectedType == .book {
                    epubDropZone
                }

                ruleDivider

                sectionLabel("文件与链接")

                HStack(spacing: 8) {
                    fieldBox {
                        Text(draft.localFilePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "未关联本地文件")
                            .foregroundStyle(draft.localFilePath == nil ? Theme.ink3 : Theme.ink2)
                            .lineLimit(1)
                    }
                    secondaryButton("选取…") { pickLocalFile() }
                    secondaryButton("清除", disabled: draft.localFilePath == nil) { draft.localFilePath = nil }
                }

                HStack(spacing: 8) {
                    fieldBox {
                        TextField("在线观看 / 收听 / 阅读链接", text: $draft.webURL)
                    }
                    secondaryButton(
                        isFetchingMetadata ? "提取中…" : "提取信息",
                        disabled: isFetchingMetadata || draft.webURL.trimmed.isEmpty
                    ) { fetchLinkMetadata() }
                }

                if selectedType == .music {
                    fieldBox {
                        TextField("Apple Music 专辑链接", text: $draft.appleMusicURL)
                    }
                }

                if metadataError {
                    Text("未能从链接获取信息，可直接手动填写。")
                        .font(Theme.cardMeta)
                        .foregroundStyle(Theme.ink2)
                }

                ruleDivider

                sectionLabel("分类标注")

                fieldBox {
                    TextField("标签（多个用逗号分隔，如：科幻, 悬疑）", text: $draft.tags)
                }

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("评分")
                            .font(Theme.cardMeta)
                            .foregroundStyle(Theme.ink3)
                        RatingStars(rating: draft.rating, size: 14) { draft.rating = $0 }
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("状态")
                            .font(Theme.cardMeta)
                            .foregroundStyle(Theme.ink3)
                        Picker("", selection: $draft.status) {
                            ForEach(MediaStatus.allCases, id: \.self) { status in
                                Text(status.label(for: selectedType)).tag(status)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 220)
                    }
                }
                .padding(.top, 2)
            }
            .padding(22)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(Theme.ink3)
            .tracking(0.5)
    }

    private var ruleDivider: some View {
        Rectangle().fill(Theme.rule).frame(height: 1).padding(.vertical, 4)
    }

    // MARK: - EPUB 封面提取

    private var epubDropZone: some View {
        HStack(spacing: 10) {
            Button {
                guard let path = FileService.shared.pickFile(allowedTypes: ["epub"], prompt: "选择 EPUB 文件") else { return }
                extractEPUB(from: path)
            } label: {
                HStack(spacing: 5) {
                    if isExtractingCover {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "book.closed")
                            .font(.system(size: 11))
                    }
                    Text(isExtractingCover ? "提取中…" : "从 EPUB 提取封面")
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.amberOn)
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(Theme.amberBtn)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isExtractingCover)

            Text(coverMessage ?? "或将 .epub 文件拖入此区域")
                .font(Theme.cardMeta)
                .foregroundStyle(coverMessage == nil ? Theme.ink3 : Theme.amber)
                .lineLimit(1)

            Spacer()
        }
        .padding(7)
        .background(isEPUBDropTargeted ? Theme.amber.opacity(0.10) : Theme.well)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isEPUBDropTargeted ? Theme.amber : Theme.rule, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .onDrop(of: [UTType.fileURL], isTargeted: $isEPUBDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            // 拖入的返回可能在后台线程，回主线程后再处理
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let nsurl = item as? NSURL {
                    url = nsurl as URL
                } else {
                    url = nil
                }
                Task { @MainActor in
                    guard let url else { return }
                    guard url.pathExtension.lowercased() == "epub" else {
                        coverMessage = "仅支持 .epub 文件"
                        return
                    }
                    extractEPUB(from: url.path)
                }
            }
            return true
        }
    }

    private func extractEPUB(from path: String) {
        epubTask?.cancel()
        isExtractingCover = true
        coverMessage = nil
        epubTask = Task {
            let coverPath = await EPUBService.shared.extractCoverAsync(from: path)
            guard !Task.isCancelled else { return }
            isExtractingCover = false
            if let coverPath {
                applyLocalCover(coverPath)
                coverMessage = "已从 EPUB 提取封面"
            } else {
                coverMessage = "未能从该 EPUB 中提取封面"
            }
        }
    }

    // MARK: - 底栏

    private var footer: some View {
        HStack(spacing: 8) {
            if isEditing {
                secondaryButton("取消") { cancelEditing() }

                if selectedResultID != nil {
                    Text("已选用一条搜索结果，可修改后确认收录。")
                        .font(Theme.cardMeta)
                        .foregroundStyle(Theme.ink3)
                        .lineLimit(1)
                }

                Spacer()

                primaryButton("确认收录", disabled: draft.title.trimmed.isEmpty) { confirmAdd() }
            } else {
                Button {
                    startManualAdd()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 11))
                        Text("手动录入 / 链接提取")
                    }
                    .font(Theme.control)
                    .foregroundStyle(Theme.ink2)
                }
                .buttonStyle(.plain)
                .help("搜不到时可自己输入，或粘贴网页链接提取封面")

                Spacer()

                if !results.isEmpty {
                    Text("\(results.count) 条结果 · 选用后预填表单")
                        .font(Theme.cardMeta)
                        .foregroundStyle(Theme.ink3)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }

    // MARK: - 按钮样式

    /// 主按钮：琥珀底 + 琥珀上文字（v3 主操作语汇）；disabled 时降透明度
    private func primaryButton(
        _ title: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.control)
                .foregroundStyle(Theme.amberOn)
                .padding(.horizontal, 16)
                .frame(height: 30)
                .background(Theme.amberBtn)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(disabled ? 0.45 : 1)
        .disabled(disabled)
    }

    private func secondaryButton(
        _ title: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.ink2)
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(Theme.well)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Theme.rule, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .opacity(disabled ? 0.45 : 1)
        .disabled(disabled)
    }

    // MARK: - 输入框容器

    /// 输入框容器：well 底 + 圆角；textFieldStyle / 字体级联到内部控件
    private func fieldBox<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .textFieldStyle(.plain)
            .font(Theme.body)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Theme.well)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
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

        // 快照当前类型，避免等待期间用户切换类型导致结果错位
        let type = selectedType
        isSearching = true
        searchTask = Task {
            let searched = await MetadataService.shared.search(query: q, type: type)
            // 只接受最新一次搜索的回写，晚返回的旧请求直接丢弃
            guard sequence == searchSequence, !Task.isCancelled else { return }
            results = searched
            isSearching = false
        }
    }

    // MARK: - 选用与手动录入

    /// 选用搜索结果：预填表单后进入编辑
    private func choose(_ result: SearchResult) {
        selectedResultID = result.id
        draft = EntryDraft(
            title: result.title,
            creator: result.creator ?? "",
            year: result.year.map(String.init) ?? "",
            synopsis: result.synopsis ?? "",
            genre: result.genre ?? "",
            coverURL: result.coverURL ?? "",
            webURL: result.webURL ?? "",
            appleMusicURL: result.appleMusicURL ?? "",
            albumName: result.albumName ?? ""
        )
        coverPreview = nil
        coverMessage = nil
        metadataError = false
        isEditing = true
    }

    private func startManualAdd() {
        selectedResultID = nil
        draft = EntryDraft()
        coverPreview = nil
        coverMessage = nil
        metadataError = false
        isEditing = true
    }

    private func cancelEditing() {
        isEditing = false
        selectedResultID = nil
        draft = EntryDraft()
        coverPreview = nil
        coverMessage = nil
        metadataError = false
    }

    // MARK: - 确认收录

    private func confirmAdd() {
        let title = draft.title.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }

        var item = MediaItem(title: title, type: selectedType)
        item.creator = draft.creator.trimmed.nilIfEmpty
        item.year = Int(draft.year.trimmingCharacters(in: .whitespaces))
        item.synopsis = draft.synopsis.trimmed.nilIfEmpty
        item.genre = draft.genre.trimmed.nilIfEmpty
        item.coverURL = draft.coverURL.trimmed.nilIfEmpty
        item.localCoverPath = draft.localCoverPath
        item.albumName = draft.albumName.trimmed.nilIfEmpty
        item.appleMusicURL = draft.appleMusicURL.trimmed.nilIfEmpty
        item.webURL = draft.webURL.trimmed.nilIfEmpty
        item.localFilePath = draft.localFilePath
        item.tags = draft.tags
            .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == "、" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        item.rating = draft.rating
        item.status = draft.status

        store.add(item)
        dismiss()
    }

    // MARK: - 封面与文件

    private func pickCoverImage() {
        guard let path = FileService.shared.pickCoverImage() else { return }
        applyLocalCover(path)
    }

    private func applyLocalCover(_ path: String) {
        draft.localCoverPath = path
        coverPreview = NSImage(contentsOfFile: path)
    }

    /// 各类型可关联的本地文件扩展名
    private var localFileTypes: [String] {
        switch selectedType {
        case .movie: return ["mp4", "mkv", "mov", "avi", "m4v", "wmv"]
        case .music: return ["mp3", "flac", "wav", "m4a", "aac", "ogg", "aiff"]
        case .book:  return ["epub", "pdf", "mobi", "azw3", "txt"]
        }
    }

    private func pickLocalFile() {
        let prompt: String
        switch selectedType {
        case .movie: prompt = "选择影片文件"
        case .music: prompt = "选择音频文件"
        case .book:  prompt = "选择电子书文件"
        }
        guard let path = FileService.shared.pickFile(allowedTypes: localFileTypes, prompt: prompt) else { return }
        draft.localFilePath = path
    }

    // MARK: - 链接元数据提取

    private func fetchLinkMetadata() {
        let link = draft.webURL.trimmingCharacters(in: .whitespaces)
        guard !link.isEmpty else { return }

        // 取消上一次提取并递增序号，旧请求晚返回时直接丢弃
        metadataTask?.cancel()
        metadataSequence += 1
        let sequence = metadataSequence

        isFetchingMetadata = true
        metadataError = false
        metadataTask = Task {
            let meta = await LinkMetadataService.shared.fetch(from: link)
            guard sequence == metadataSequence, !Task.isCancelled else { return }
            isFetchingMetadata = false
            guard let meta else {
                metadataError = true
                return
            }
            // 只补空缺：标题 / 简介 / 封面链接没填时才填入，不覆盖用户已输入内容
            if draft.title.isEmpty, let title = meta.title { draft.title = title }
            if draft.synopsis.isEmpty, let description = meta.description { draft.synopsis = description }
            if draft.coverURL.isEmpty, let coverURL = meta.coverURL { draft.coverURL = coverURL }
        }
    }
}

// MARK: - 编辑表单草稿

/// 录入表单的草稿值（确认收录时逐项写入 MediaItem）
private struct EntryDraft {
    var title = ""
    var creator = ""
    var year = ""
    var synopsis = ""
    var genre = ""
    var coverURL = ""
    var localCoverPath: String?
    var localFilePath: String?
    var webURL = ""
    var appleMusicURL = ""
    var albumName = ""
    var tags = ""
    var rating = 0
    var status: MediaStatus = .planned
}

// MARK: - 单条搜索结果

private struct ResultRow: View {

    let result: SearchResult
    let isSelected: Bool
    let onChoose: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RemoteThumbnailView(urlString: result.coverURL)
                .frame(width: 56)
                .frame(height: 56 / result.type.coverAspectRatio, alignment: .top)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let creator = result.creator, !creator.isEmpty {
                        Text(creator).lineLimit(1)
                    }
                    if let year = result.year {
                        Text(String(year)).monospacedDigit()
                    }
                }
                .font(Theme.cardMeta)
                .foregroundStyle(Theme.ink2)

                if let synopsis = result.synopsis, !synopsis.isEmpty {
                    Text(synopsis)
                        .font(Theme.cardMeta)
                        .foregroundStyle(Theme.ink3)
                        .lineLimit(2)
                        .lineSpacing(2)
                        .padding(.top, 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            chooseButton
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered || isSelected ? Theme.well : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) { isHovered = hovering }
        }
    }

    @ViewBuilder
    private var chooseButton: some View {
        if isSelected {
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                Text("已选用")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.ink3)
            .frame(width: 72, height: 26)
        } else {
            Button(action: onChoose) {
                Text("选用")
                    .font(Theme.control)
                    .foregroundStyle(Theme.amberOn)
                    .frame(width: 72, height: 26)
                    .background(Theme.amberBtn)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 远程缩略封面

/// 搜索结果缩略封面：远程加载 + 内存缓存（列表里大量复用，避免反复下载）
private struct RemoteThumbnailView: View {

    let urlString: String?

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else if urlString != nil {
                ZStack {
                    Theme.well
                    ProgressView()
                        .controlSize(.small)
                }
            } else {
                ZStack {
                    Theme.well
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(Theme.ink3)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .task(id: urlString) {
            guard let urlString, let url = URL(string: urlString) else { return }
            if let cached = RemoteThumbCache.shared.cache.object(forKey: urlString as NSString) {
                image = cached
                return
            }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let loaded = NSImage(data: data) {
                    RemoteThumbCache.shared.cache.setObject(loaded, forKey: urlString as NSString)
                    image = loaded
                }
            } catch {
                // 下载失败保持占位，不打断列表交互
            }
        }
    }
}

/// 缩略封面内存缓存（仅主线程访问）
@MainActor
private final class RemoteThumbCache {
    static let shared = RemoteThumbCache()
    let cache = NSCache<NSString, NSImage>()
}

// MARK: - 工具

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}