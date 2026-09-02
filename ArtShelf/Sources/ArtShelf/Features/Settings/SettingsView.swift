import SwiftUI
import AppKit

/// 设置页：外观 / 数据 / 存储 / 关于
///
/// 作为「设置」场景内容（⌘,），尺寸固定为适合设置窗口的紧凑布局。
struct SettingsView: View {

    @Environment(LibraryStore.self) private var store
    /// 导入结果提示文案（nil 时隐藏）
    @State private var importMessage: String?
    /// 导出结果提示文案（nil 时隐藏）
    @State private var exportMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                appearanceSection
                iconSection
                dataSection
                storageSection
                aboutSection
            }
            .padding(24)
        }
        .frame(width: 500, height: 640)
        .scrollIndicators(.hidden)
        .background(Theme.bg)
    }

    // MARK: - 分区外壳

    /// 分区：小标题 + 面板卡片
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.ink3)
            content()
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.panel)
                .clipShape(RoundedRectangle(cornerRadius: Theme.panelCorner, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.panelCorner, style: .continuous)
                        .strokeBorder(Theme.rule, lineWidth: 1)
                )
        }
    }

    /// 次级操作按钮：内凹槽底 + 圆角（可选图标）
    private func actionButton(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11.5))
                }
                Text(title)
                    .font(Theme.control)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(Theme.well)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 外观

    private var appearanceSection: some View {
        section(title: "外观 · 主题") {
            HStack(spacing: 18) {
                ForEach(AppTheme.allCases) { theme in
                    themeSwatch(theme)
                }
            }
        }
    }

    /// 主题色样：迷你窗口预览（画布底 + 面板卡 + 文字条 + 强调色点），选中描边加粗
    private func themeSwatch(_ theme: AppTheme) -> some View {
        let selected = ThemeSettings.shared.theme == theme
        return Button {
            ThemeSettings.shared.theme = theme
        } label: {
            VStack(spacing: 6) {
                swatchCanvas(theme)
                    .frame(width: 56, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(selected ? Theme.amber : Theme.rule, lineWidth: selected ? 2 : 1)
                    )
                Text(theme.title)
                    .font(.system(size: 11))
                    .foregroundStyle(selected ? Theme.ink : Theme.ink3)
            }
        }
        .buttonStyle(.plain)
    }

    /// 迷你窗口画布（固定色值，不随当前主题变化；跟随系统为半浅半深拼色）
    @ViewBuilder
    private func swatchCanvas(_ theme: AppTheme) -> some View {
        if theme == .system {
            HStack(spacing: 0) {
                swatchContent(bg: Color(nsColor: Theme.hex(0xF5F4F0)), panel: Color(nsColor: Theme.hex(0xFFFFFF)), ink: Color(nsColor: Theme.hex(0x1B1D23)))
                swatchContent(bg: Color(nsColor: Theme.hex(0x0D0E11)), panel: Color(nsColor: Theme.hex(0x17191F)), ink: Color(nsColor: Theme.hex(0xF2F3F6)))
            }
        } else {
            swatchContent(bg: theme.palette.bg, panel: theme.palette.panel, ink: theme.palette.ink)
        }
    }

    /// 单侧迷你窗口：画布底 + 面板条 + 文字条 + 强调色点
    private func swatchContent(bg: Color, panel: Color, ink: Color) -> some View {
        ZStack(alignment: .topLeading) {
            bg
            VStack(alignment: .leading, spacing: 3) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(panel)
                    .frame(width: 30, height: 12)
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(ink)
                    .frame(width: 18, height: 2.5)
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(ink.opacity(0.5))
                    .frame(width: 24, height: 2.5)
            }
            .padding(5)
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(Theme.amber)
                .frame(width: 5, height: 5)
                .padding(4)
        }
    }

    // MARK: - 应用图标

    private var iconSection: some View {
        section(title: "应用图标") {
            HStack(spacing: 18) {
                ForEach(AppIconOption.allCases) { icon in
                    iconSwatch(icon)
                }
            }
        }
    }

    /// 图标色样：缩略图（底版对齐描边）+ 名称，点击即切换 Dock / 应用图标
    private func iconSwatch(_ icon: AppIconOption) -> some View {
        let selected = ThemeSettings.shared.appIcon == icon
        return Button {
            ThemeSettings.shared.appIcon = icon
        } label: {
            VStack(spacing: 6) {
                Group {
                    if let image = icon.image {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.well)
                    }
                }
                .frame(width: 64, height: 64)
                // 描边对齐图标底版边缘（底版占画布 824/1024，四周留白约 6.3pt）
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(selected ? Theme.amber : Theme.rule, lineWidth: selected ? 2 : 1)
                        .padding(6.3)
                )
                Text(icon.title)
                    .font(.system(size: 11))
                    .foregroundStyle(selected ? Theme.ink : Theme.ink3)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 数据

    private var dataSection: some View {
        section(title: "数据") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    actionButton("导出 JSON…", systemImage: "square.and.arrow.up") {
                        performExport()
                    }
                    actionButton("从 JSON 导入…", systemImage: "square.and.arrow.down") {
                        performImport()
                    }
                }
                if let message = exportMessage {
                    Text(message)
                        .font(Theme.body)
                        .foregroundStyle(Theme.ink2)
                }
                if let message = importMessage {
                    Text(message)
                        .font(Theme.body)
                        .foregroundStyle(Theme.ink2)
                }
            }
        }
    }

    /// 导出 JSON 并展示结果提示（成功/取消保持静默，仅失败提示）
    private func performExport() {
        switch LibraryIO.exportLibrary(store: store) {
        case .exported, .cancelled:
            exportMessage = nil
        case .failed(let reason):
            exportMessage = "导出失败：\(reason)"
        }
    }

    /// 导入 JSON 并展示结果提示
    private func performImport() {
        switch LibraryIO.importLibrary(store: store) {
        case .imported(let count):
            importMessage = count > 0 ? "已导入 \(count) 件藏品" : "未导入新条目（文件为空或条目均已存在）"
        case .cancelled:
            importMessage = nil
        case .failed(let reason):
            importMessage = "导入失败：\(reason)"
        }
    }

    // MARK: - 存储

    private var storageSection: some View {
        section(title: "存储") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text(LibraryPaths.appDirectory.path)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(Theme.ink2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 12)
                    actionButton("在 Finder 中打开") {
                        NSWorkspace.shared.open(LibraryPaths.appDirectory)
                    }
                }
                Text("封面缓存存放于 covers/ 子目录；删除藏品时，应用自管的封面文件会一并清理。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.ink3)
            }
        }
    }

    // MARK: - 关于

    private var aboutSection: some View {
        section(title: "关于") {
            HStack(spacing: 12) {
                prismLogo
                VStack(alignment: .leading, spacing: 3) {
                    Text("ArtShelf")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("\(appVersion) · macOS 14+ · 100% 本地优先")
                        .font(Theme.body)
                        .foregroundStyle(Theme.ink3)
                }
            }
        }
    }

    /// 版本号单一来源：取 Info.plist 的 CFBundleShortVersionString，读不到时兜底
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.2.4"
    }

    /// 品牌棱镜标（与顶栏一致）
    private var prismLogo: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(AngularGradient(
                colors: Theme.prismColors,
                center: .center
            ))
            .frame(width: 22, height: 22)
    }
}