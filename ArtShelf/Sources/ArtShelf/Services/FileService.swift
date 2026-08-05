import AppKit
import Foundation
import UniformTypeIdentifiers

/// 文件 / 链接打开服务
final class FileService {

    static let shared = FileService()
    private init() {}

    // MARK: - 打开本地文件

    /// 用系统默认应用打开本地文件
    @discardableResult
    func openLocalFile(at path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            print("⚠️ 文件不存在: \(path)")
            return false
        }
        return NSWorkspace.shared.open(url)
    }

    /// 打开网页链接
    @discardableResult
    func openURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return NSWorkspace.shared.open(url)
    }

    // MARK: - 文件选择器

    /// 弹出文件选择面板，返回选中文件路径
    func pickFile(allowedTypes: [String], prompt: String = "选择文件") -> String? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = prompt
        if !allowedTypes.isEmpty {
            panel.allowedContentTypes = allowedTypes.compactMap { UTType(filenameExtension: $0) }
        }
        let response = panel.runModal()
        return response == .OK ? panel.url?.path : nil
    }

    /// 弹出文件夹选择面板，返回选中目录路径
    func pickDirectory(prompt: String = "选择文件夹") -> String? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = prompt
        let response = panel.runModal()
        return response == .OK ? panel.url?.path : nil
    }

    /// 选择封面图片
    func pickCoverImage() -> String? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "选择封面图片"
        panel.allowedContentTypes = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "heif", "webp"]
            .compactMap { UTType(filenameExtension: $0) }
        let response = panel.runModal()
        return response == .OK ? panel.url?.path : nil
    }

    // MARK: - 打开方式

    /// 根据媒体类型智能打开
    func openMedia(_ item: MediaItem) {
        // 优先打开本地文件
        if let localPath = item.localFilePath,
           FileManager.default.fileExists(atPath: localPath) {
            openLocalFile(at: localPath)
            return
        }
        // 其次打开在线链接
        if let webURL = item.webURL {
            openURL(webURL)
            return
        }
        // 音乐：尝试 Apple Music
        if item.type == .music, let appleMusic = item.appleMusicURL {
            openURL(appleMusic)
            return
        }
        print("⚠️ 没有可打开的文件或链接")
    }

    /// 判断本地文件是否存在
    func localFileExists(at path: String?) -> Bool {
        guard let path = path else { return false }
        return FileManager.default.fileExists(atPath: path)
    }
}
