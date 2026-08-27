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
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

            PaperRule()

            HStack(alignment: .top, spacing: 28) {
                leftPanel
                    .frame(width: 220)

                rightPanel
            }
            .padding(24)
        }
        .background(ArtShelfStyle.paper)
        .frame(minWidth: 740, minHeight: 580)
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

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if isEditingTitle {
                        TextField("标题", text: $item.title)
                            .font(.system(size: 22, weight: .bold))
                            .textFieldStyle(.plain)
                            .lineLimit(1)
                            .onSubmit { isEditingTitle = false }
                    } else {
                        Text(item.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(ArtShelfStyle.ink)
                            .lineLimit(1)
                    }

                    Button {
                        isEditingTitle.toggle()
                    } label: {
                        Image(systemName: isEditingTitle ? "checkmark" : "pencil")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isEditingTitle ? ArtShelfStyle.accent : ArtShelfStyle.inkTertiary)
                            .frame(width: 24, height: 24)
                            .background(ArtShelfStyle.well, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help(isEditingTitle ? "完成编辑" : "编辑标题")

                    // 类型胶囊
                    Text(item.type.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ArtShelfStyle.inkSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(ArtShelfStyle.well)
                        )
                }

                if !bylineText.isEmpty {
                    Text(bylineText)
                        .font(.system(size: 12))
                        .foregroundStyle(ArtShelfStyle.inkSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button("完成") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(ArtShelfStyle.accent)
                .controlSize(.regular)
                .keyboardShortcut(.return, modifiers: .command)
        }
    }

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
        VStack(spacing: 14) {
            CoverImageView(
                localPath: item.localCoverPath,
                remoteURL: item.coverURL,
                aspectRatio: item.type.coverAspectRatio,
                cornerRadius: ArtShelfStyle.panelRadius
            )
            .shadow(color: ArtShelfStyle.coverShadow, radius: 8, y: 3)

            coverActionButtons

            // 评分
            VStack(spacing: 5) {
                RatingStars(rating: item.rating) { newRating in
                    item.rating = newRating
                }
                Text(item.rating > 0 ? "\(item.rating) / 5 分" : "未评分")
                    .font(.system(size: 11))
                    .foregroundStyle(ArtShelfStyle.inkTertiary)
            }
            .padding(.vertical, 4)

            // 操作主按钮
            VStack(spacing: 8) {
                if FileService.shared.localFileExists(at: item.localFilePath) {
                    Button {
                        FileService.shared.openMedia(item)
                    } label: {
                        Label("打开本地文件", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ArtShelfStyle.accent)
                }

                if let webURL = item.webURL, !webURL.isEmpty, !FileService.shared.localFileExists(at: item.localFilePath) {
                    Button {
                        FileService.shared.openURL(webURL)
                    } label: {
                        Label(item.type == .music ? "Apple Music 播放" : "在线观看", systemImage: "arrow.up.right.square")
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

            // 状态选择器
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

    private var coverActionButtons: some View {
        VStack(spacing: 6) {
            Button {
                if let path = FileService.shared.pickCoverImage() {
                    item.localCoverPath = path
                }
            } label: {
                Label("更换封面", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isExtractingCover)

            if item.type == .book,
               item.localFilePath?.hasSuffix(".epub") == true,
               item.localCoverPath == nil {

                if isExtractingCover {
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
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

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

    private var rightPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                synopsisSection
                notesSection
                bibliographySection
                tagsSection
                fileSection
                webURLSection

                PaperRule()
                    .padding(.top, 4)

                Button(role: .destructive) {
                    store.delete(item)
                    dismiss()
                } label: {
                    Label("删除此收藏", systemImage: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red.opacity(0.85))
            }
            .padding(.trailing, 8)
        }
        .hideScrollIndicators()
    }

    // MARK: - 简介

    private var synopsisSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: "简介")
            ZStack(alignment: .topLeading) {
                if (item.synopsis ?? "").isEmpty {
                    Text("添加内容简介……")
                        .font(.system(size: 13))
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                TextEditor(text: synopsisBinding)
                    .font(.system(size: 13))
                    .foregroundStyle(ArtShelfStyle.ink)
                    .lineSpacing(4)
                    .padding(8)
                    .frame(minHeight: 64)
                    .scrollContentBackground(.hidden)
            }
            .wellBackground(radius: 8)
        }
    }

    private var synopsisBinding: Binding<String> {
        Binding(
            get: { item.synopsis ?? "" },
            set: { item.synopsis = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }

    // MARK: - 我的感想

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: "我的感想 / 笔记")
            ZStack(alignment: .topLeading) {
                if item.notes.isEmpty {
                    Text("记录你的评语、读后感或心情……")
                        .font(.system(size: 13))
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $item.notes)
                    .font(ArtShelfStyle.body)
                    .lineSpacing(4)
                    .padding(8)
                    .frame(minHeight: 88)
                    .scrollContentBackground(.hidden)
            }
            .wellBackground(radius: 8)
        }
    }

    // MARK: - 作品详细信息

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
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: "作品信息")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(metadataRows.enumerated()), id: \.offset) { entry in
                    if entry.offset > 0 {
                        PaperRule()
                            .padding(.vertical, 6)
                    }
                    infoRow(label: entry.element.label, value: entry.element.value)
                }
            }
            .padding(12)
            .panelBackground(radius: 8)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(ArtShelfStyle.inkTertiary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 12.5))
                .foregroundStyle(ArtShelfStyle.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 标签

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "标签分类")

            if !item.tags.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(item.tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                                .font(.system(size: 11.5, weight: .medium))
                            Button {
                                item.tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .opacity(0.6)
                            }
                            .buttonStyle(.plain)
                        }
                        .foregroundStyle(ArtShelfStyle.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(ArtShelfStyle.well))
                    }
                }
            }

            HStack {
                Image(systemName: "tag")
                    .font(.system(size: 11))
                    .foregroundStyle(ArtShelfStyle.inkTertiary)
                TextField("输入新标签后按回车…", text: $newTag)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit {
                        let tag = newTag.trimmingCharacters(in: .whitespaces)
                        if !tag.isEmpty && !item.tags.contains(tag) {
                            item.tags.append(tag)
                        }
                        newTag = ""
                    }
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .wellBackground(radius: 7)
        }
    }

    // MARK: - 本地文件

    private var fileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "本地关联文件")

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
                        Image(systemName: "play.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ArtShelfStyle.accent)
                    .help("打开文件")

                    Button {
                        item.localFilePath = nil
                        if item.localCoverPath?.contains("ArtShelf/covers") == true {
                            item.localCoverPath = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
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
                    .controlSize(.small)
                }
            }
            .padding(10)
            .wellBackground(radius: 8)
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
                        .frame(height: 28)
                        .wellBackground(radius: 7)
                        .onSubmit { saveWebURL() }

                    Button("保存") { saveWebURL() }
                        .buttonStyle(.borderedProminent)
                        .tint(ArtShelfStyle.accent)
                        .controlSize(.small)

                    Button("取消") {
                        isEditingWebURL = false
                        webURLDraft = item.webURL ?? ""
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
                        .foregroundStyle(ArtShelfStyle.accent)
                        .help("打开链接")

                        Button {
                            webURLDraft = webURL
                            isEditingWebURL = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                        .help("编辑链接")

                        Button {
                            item.webURL = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
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
                .padding(10)
                .wellBackground(radius: 8)
            }
        }
    }

    private func saveWebURL() {
        let trimmed = webURLDraft.trimmingCharacters(in: .whitespaces)
        item.webURL = trimmed.isEmpty ? nil : trimmed
        isEditingWebURL = false
    }
}
