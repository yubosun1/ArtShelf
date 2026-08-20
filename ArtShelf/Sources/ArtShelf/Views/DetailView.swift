import SwiftUI
import AppKit

struct DetailView: View {

    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var item: MediaItem
    @State private var newTag: String = ""
    @State private var isExtractingCover = false
    @State private var isEditingTitle = false
    @State private var isEditingWebURL = false
    @State private var webURLDraft = ""

    init(item: MediaItem) {
        _item = State(initialValue: item)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 22)
                .padding(.top, 18)

            PaperRule()
                .padding(.top, 14)

            HStack(alignment: .top, spacing: 26) {
                leftPanel
                    .frame(width: 210)

                rightPanel
            }
            .padding(22)
        }
        .background(ArtShelfStyle.paper)
        .frame(minWidth: 700, minHeight: 540)
        .onAppear {
            if item.lastViewedDate == nil || !item.viewedToday {
                item.lastViewedDate = Date()
                store.update(item)
            }
        }
        .onChange(of: item) { _, newItem in
            store.update(newItem)
        }
    }

    // MARK: - 页眉

    /// 书衣页版式：标题 + 署名行排在纸面最上，右侧仅留「完成」。
    /// 整体不用 surface 色带，横线之下直接是内容。
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    if isEditingTitle {
                        TextField("标题", text: $item.title)
                            .font(ArtShelfStyle.serifTitle(24))
                            .textFieldStyle(.plain)
                            .lineLimit(1)
                            .onSubmit { isEditingTitle = false }
                    } else {
                        Text(item.title)
                            .font(ArtShelfStyle.serifTitle(24))
                            .foregroundStyle(ArtShelfStyle.ink)
                            .lineLimit(1)
                    }

                    Button {
                        isEditingTitle.toggle()
                    } label: {
                        Image(systemName: isEditingTitle ? "checkmark" : "pencil")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isEditingTitle ? ArtShelfStyle.accent : ArtShelfStyle.inkTertiary)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(isEditingTitle ? "完成编辑" : "编辑标题")
                }

                // 署名行：创作人 · 年份 · 类型，全空则不显示
                if !bylineText.isEmpty {
                    Text(bylineText)
                        .font(ArtShelfStyle.byline)
                        .foregroundStyle(ArtShelfStyle.inkSecondary)
                        .lineLimit(1)
                }
            }

            // 类型标签——发丝线描边的小标签，不再用填充胶囊
            Text(item.type.rawValue)
                .font(ArtShelfStyle.cardMeta)
                .foregroundStyle(ArtShelfStyle.inkSecondary)
                .padding(.horizontal, 9)
                .frame(height: 20)
                .overlay(Capsule().strokeBorder(ArtShelfStyle.rule, lineWidth: 1))

            Spacer()

            Button("完成") { dismiss() }
                .keyboardShortcut(.return, modifiers: .command)
        }
    }

    /// 署名行：creator、year、genre 中非空项用「 · 」连接
    private var bylineText: String {
        var parts: [String] = []
        if let creator = item.creator, !creator.isEmpty {
            parts.append(creator)
        }
        if let year = item.year {
            parts.append(String(year))
        }
        if let genre = item.genre, !genre.isEmpty {
            parts.append(genre)
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - 左侧面板

    private var leftPanel: some View {
        VStack(spacing: 13) {
            CoverImageView(
                localPath: item.localCoverPath,
                remoteURL: item.coverURL,
                aspectRatio: item.type.coverAspectRatio,
                cornerRadius: ArtShelfStyle.cardRadius
            )

            // 封面操作按钮
            coverActionButtons

            VStack(spacing: 3) {
                RatingStars(rating: item.rating) { newRating in
                    item.rating = newRating
                }
                Text(item.rating > 0 ? "\(item.rating) / 5" : "点击评分")
                    .font(ArtShelfStyle.cardMeta)
                    .foregroundStyle(ArtShelfStyle.inkTertiary)
            }
            .padding(.vertical, 2)

            // 打开按钮
            VStack(spacing: 8) {
                if FileService.shared.localFileExists(at: item.localFilePath) {
                    Button {
                        FileService.shared.openMedia(item)
                    } label: {
                        Label("打开本地文件", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let webURL = item.webURL, !webURL.isEmpty, !FileService.shared.localFileExists(at: item.localFilePath) {
                    Button {
                        FileService.shared.openURL(webURL)
                    } label: {
                        Label(item.type == .music ? "在 Apple Music 中打开" : "在线观看", systemImage: "globe")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if item.type == .music, let appleMusicURL = item.appleMusicURL,
                   !FileService.shared.localFileExists(at: item.localFilePath) {
                    Button {
                        FileService.shared.openURL(appleMusicURL)
                    } label: {
                        Label("Apple Music", systemImage: "music.note")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }

            // 状态选择
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(title: "状态")
                Picker("状态", selection: $item.status) {
                    ForEach(MediaStatus.allCases, id: \.self) { status in
                        Text(status.label(for: item.type)).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    // MARK: - 封面操作按钮

    private var coverActionButtons: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    if let path = FileService.shared.pickCoverImage() {
                        item.localCoverPath = path
                    }
                } label: {
                    Label("更换封面", systemImage: "photo")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .disabled(isExtractingCover)
            }

            // 从 EPUB 提取封面
            if item.type == .book,
               item.localFilePath?.hasSuffix(".epub") == true,
               item.localCoverPath == nil {

                if isExtractingCover {
                    // 提取中：显示进度指示器
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在提取封面…")
                            .font(.caption)
                            .foregroundStyle(ArtShelfStyle.inkSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                } else {
                    Button {
                        extractEPUBCover()
                    } label: {
                        Label("从 EPUB 提取封面", systemImage: "doc.zipper")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - 异步提取 EPUB 封面

    private func extractEPUBCover() {
        guard let path = item.localFilePath else { return }
        isExtractingCover = true
        Task {
            let coverPath = await EPUBService.shared.extractCoverAsync(from: path)
            await MainActor.run {
                if let coverPath {
                    item.localCoverPath = coverPath
                }
                isExtractingCover = false
            }
        }
    }

    // MARK: - 右侧面板

    /// 阅读区在前（简介、我的感想），其后是书目信息与管理区。
    private var rightPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 阅读区
                synopsisSection

                // 我的感想
                notesSection

                // 书目信息（原元数据定义列表）
                bibliographySection

                // 标签
                tagsSection

                // 本地文件
                fileSection

                // 在线链接
                webURLSection

                // 删除
                PaperRule()
                Button(role: .destructive) {
                    store.delete(item)
                    dismiss()
                } label: {
                    Label("删除此收藏", systemImage: "trash")
                }
            }
            .padding(.trailing, 8)
        }
    }

    // MARK: - 简介

    /// 简介始终展示、原地编辑：有值是一段衬线段落，编辑时读起来像书衣文案。
    /// 无边框编辑——文本直接排在纸上，不垫底色。
    private var synopsisSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: "简介")
            ZStack(alignment: .topLeading) {
                if (item.synopsis ?? "").isEmpty {
                    Text("补充一段简介……")
                        .font(ArtShelfStyle.serifBody(13))
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                TextEditor(text: synopsisBinding)
                    .font(ArtShelfStyle.serifBody(13.5))
                    .foregroundStyle(ArtShelfStyle.ink)
                    .lineSpacing(6)
                    .frame(minHeight: 60)
                    .scrollContentBackground(.hidden)
            }
        }
    }

    /// 空内容存为 nil（避免存一串空格），有内容时原样保存
    private var synopsisBinding: Binding<String> {
        Binding(
            get: { item.synopsis ?? "" },
            set: { item.synopsis = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }

    // MARK: - 我的感想

    /// 个人笔记同样无边框，直接排在纸上
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: "我的感想")
            ZStack(alignment: .topLeading) {
                if item.notes.isEmpty {
                    Text("写下你的想法、评价、摘录……")
                        .font(.system(size: 13))
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $item.notes)
                    .font(ArtShelfStyle.body)
                    .lineSpacing(4)
                    .frame(minHeight: 90)
                    .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - 书目信息（元数据字段表）

    private struct MetaRow {
        let label: String
        let value: String
    }

    private var metadataRows: [MetaRow] {
        var rows: [MetaRow] = []
        if let creator = item.creator, !creator.isEmpty {
            rows.append(MetaRow(
                label: item.type == .book ? "作者" : (item.type == .music ? "艺术家" : "导演"),
                value: creator
            ))
        }
        if let albumName = item.albumName, !albumName.isEmpty {
            rows.append(MetaRow(label: "专辑", value: albumName))
        }
        if let year = item.year {
            rows.append(MetaRow(label: "年份", value: String(year)))
        }
        if let genre = item.genre, !genre.isEmpty {
            rows.append(MetaRow(label: "类型", value: genre))
        }
        rows.append(MetaRow(
            label: "添加时间",
            value: item.dateAdded.formatted(date: .abbreviated, time: .shortened)
        ))
        if let viewed = item.lastViewedDate {
            rows.append(MetaRow(
                label: "最近浏览",
                value: viewed.formatted(date: .abbreviated, time: .shortened)
            ))
        }
        return rows
    }

    private var bibliographySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "书目信息")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(metadataRows.enumerated()), id: \.offset) { entry in
                    if entry.offset > 0 {
                        PaperRule()
                            .padding(.vertical, 5)
                    }
                    infoRow(label: entry.element.label, value: entry.element.value)
                }
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(ArtShelfStyle.cardMeta)
                .foregroundStyle(ArtShelfStyle.inkTertiary)
                .frame(width: 54, alignment: .leading)
            Text(value)
                .font(ArtShelfStyle.body)
                .foregroundStyle(ArtShelfStyle.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 标签

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "标签")

            if !item.tags.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(item.tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                                .font(.system(size: 11))
                            Button {
                                item.tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 7, weight: .bold))
                                    .opacity(0.6)
                            }
                            .buttonStyle(.plain)
                        }
                        .foregroundStyle(ArtShelfStyle.ink)
                        .padding(.horizontal, 8)
                        .frame(height: 21)
                        // 描边胶囊，底色留空——印章只落在评分与选中态
                        .overlay(Capsule().strokeBorder(ArtShelfStyle.rule, lineWidth: 1))
                    }
                }
            }

            HStack {
                Image(systemName: "tag")
                    .font(.system(size: 11))
                    .foregroundStyle(ArtShelfStyle.inkTertiary)
                TextField("添加标签后按回车", text: $newTag)
                    .textFieldStyle(.plain)
                    .font(ArtShelfStyle.body)
                    .onSubmit {
                        let tag = newTag.trimmingCharacters(in: .whitespaces)
                        if !tag.isEmpty && !item.tags.contains(tag) {
                            item.tags.append(tag)
                        }
                        newTag = ""
                    }
            }
            .padding(.horizontal, 10)
            .frame(height: 27)
            .wellBackground()
        }
    }

    // MARK: - 本地文件

    private var fileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "本地文件")

            HStack {
                if let path = item.localFilePath {
                    Text(path)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(ArtShelfStyle.inkSecondary)
                        .help(path)
                    Spacer()
                    Button {
                        FileService.shared.openLocalFile(at: path)
                    } label: {
                        Image(systemName: "play.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ArtShelfStyle.inkTertiary)
                    .help("打开文件")
                    Button {
                        item.localFilePath = nil
                        // 如果移除文件，也清除封面（如果封面是从该文件提取的）
                        if item.localCoverPath?.contains("ArtShelf/covers") == true {
                            item.localCoverPath = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ArtShelfStyle.inkTertiary)
                    .help("移除关联")
                } else {
                    Text("未关联本地文件")
                        .font(.system(size: 12))
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                    Spacer()
                    Button {
                        let allowedTypes: [String]
                        switch item.type {
                        case .movie: allowedTypes = ["mp4", "mkv", "mov", "avi", "m4v", "flv", "wmv", "webm"]
                        case .music: allowedTypes = ["mp3", "flac", "aac", "m4a", "wav", "ogg", "alac"]
                        case .book:  allowedTypes = ["pdf", "epub", "txt", "mobi", "azw3", "azw", "doc", "docx"]
                        }
                        if let path = FileService.shared.pickFile(allowedTypes: allowedTypes, prompt: "选择\(item.type.rawValue)文件") {
                            item.localFilePath = path
                            // 自动从 EPUB 异步提取封面
                            if item.type == .book && path.hasSuffix(".epub") {
                                isExtractingCover = true
                                Task {
                                    let coverPath = await EPUBService.shared.extractCoverAsync(from: path)
                                    await MainActor.run {
                                        if let coverPath {
                                            item.localCoverPath = coverPath
                                        }
                                        isExtractingCover = false
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("选择文件", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - 在线链接

    private var webURLSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "在线链接")

            if isEditingWebURL {
                HStack(spacing: 6) {
                    TextField("粘贴在线观看 / 阅读链接…", text: $webURLDraft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .wellBackground()
                        .onSubmit { saveWebURL() }

                    Button {
                        saveWebURL()
                    } label: {
                        Text("保存")
                            .frame(width: 40)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        isEditingWebURL = false
                        webURLDraft = item.webURL ?? ""
                    } label: {
                        Text("取消")
                            .frame(width: 36)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                HStack {
                    if let webURL = item.webURL, !webURL.isEmpty {
                        Text(webURL)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(ArtShelfStyle.inkSecondary)
                        Spacer()
                        Button {
                            FileService.shared.openURL(webURL)
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                        .help("打开链接")
                        Button {
                            webURLDraft = webURL
                            isEditingWebURL = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                        .help("编辑链接（比如搜索到的信息页和在线观看页不是同一个网站）")
                        Button {
                            item.webURL = nil
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                        .help("移除链接")
                    } else {
                        Text("无在线链接")
                            .font(.system(size: 12))
                            .foregroundStyle(ArtShelfStyle.inkTertiary)
                        Spacer()
                        Button {
                            webURLDraft = ""
                            isEditingWebURL = true
                        } label: {
                            Label("添加链接", systemImage: "link")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    /// 保存编辑后的在线链接
    private func saveWebURL() {
        let trimmed = webURLDraft.trimmingCharacters(in: .whitespaces)
        item.webURL = trimmed.isEmpty ? nil : trimmed
        isEditingWebURL = false
    }
}
