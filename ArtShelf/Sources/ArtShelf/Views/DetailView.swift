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

    init(item: MediaItem) {
        _item = State(initialValue: item)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            PaperRule()

            HStack(alignment: .top, spacing: 26) {
                leftPanel
                    .frame(width: 200)

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

    // MARK: - 顶栏

    private var header: some View {
        HStack(spacing: 10) {
            if isEditingTitle {
                TextField("标题", text: $item.title)
                    .font(ArtShelfStyle.title(15))
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .onSubmit { isEditingTitle = false }
            } else {
                Text(item.title)
                    .font(ArtShelfStyle.title(15))
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

            Spacer()

            Text(item.type.rawValue)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ArtShelfStyle.inkSecondary)
                .padding(.horizontal, 8)
                .frame(height: 20)
                .wellBackground(radius: 5)

            Button("完成") { dismiss() }
                .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(ArtShelfStyle.surface)
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
                            .foregroundStyle(.secondary)
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

    private var rightPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 元数据
                metadataSection

                // 简介
                if let synopsis = item.synopsis, !synopsis.isEmpty {
                    synopsisSection(synopsis)
                }

                // 我的感想
                notesSection

                // 标签
                tagsSection

                // 本地文件
                fileSection

                // 在线链接
                webURLSection

                // 删除
                Divider().padding(.vertical, 4)
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

    // MARK: - 元数据

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let creator = item.creator, !creator.isEmpty {
                infoRow(label: item.type == .book ? "作者" : (item.type == .music ? "艺术家" : "导演"),
                        value: creator)
            }
            if let albumName = item.albumName, !albumName.isEmpty {
                infoRow(label: "专辑", value: albumName)
            }
            if let year = item.year {
                infoRow(label: "年份", value: String(year))
            }
            if let genre = item.genre, !genre.isEmpty {
                infoRow(label: "类型", value: genre)
            }
            infoRow(label: "添加时间", value: item.dateAdded.formatted(date: .abbreviated, time: .shortened))
            if let viewed = item.lastViewedDate {
                infoRow(label: "最近浏览", value: viewed.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(ArtShelfStyle.inkTertiary)
                .frame(width: 54, alignment: .leading)
            Text(value)
                .font(ArtShelfStyle.body)
                .foregroundStyle(ArtShelfStyle.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 简介

    private func synopsisSection(_ synopsis: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: "简介")
            Text(synopsis)
                .font(ArtShelfStyle.body)
                .foregroundStyle(ArtShelfStyle.inkSecondary)
                .lineSpacing(4.5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 我的感想

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: "我的感想")
            ZStack(alignment: .topLeading) {
                if item.notes.isEmpty {
                    Text("写下你的想法、评价、摘录……")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $item.notes)
                    .font(ArtShelfStyle.body)
                    .frame(minHeight: 110)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .wellBackground()
            }
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
                                .font(.system(size: 11, weight: .medium))
                            Button {
                                item.tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 7, weight: .bold))
                                    .opacity(0.6)
                            }
                            .buttonStyle(.plain)
                        }
                        .foregroundStyle(ArtShelfStyle.accent)
                        .padding(.horizontal, 8)
                        .frame(height: 21)
                        .background(Capsule().fill(ArtShelfStyle.accentWash))
                    }
                }
            }

            HStack {
                Image(systemName: "tag")
                    .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
                        .help(path)
                    Spacer()
                    Button {
                        FileService.shared.openLocalFile(at: path)
                    } label: {
                        Image(systemName: "play.circle")
                    }
                    .buttonStyle(.plain)
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
                    .help("移除关联")
                } else {
                    Text("未关联本地文件")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
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
            HStack {
                if let webURL = item.webURL, !webURL.isEmpty {
                    Text(webURL)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        FileService.shared.openURL(webURL)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .buttonStyle(.plain)
                    .help("打开链接")
                    Button {
                        item.webURL = nil
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.plain)
                    .help("移除链接")
                } else {
                    Text("无在线链接")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
