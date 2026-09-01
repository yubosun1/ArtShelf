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
                dataSection
                storageSection
                aboutSection
            }
            .padding(24)
        }
        .frame(width: 500, height: 620)
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
        section(title: "外观") {
            VStack(alignment: .leading, spacing: 16) {
                Text("跟随系统自动切换 · 浅色为白昼放映厅，深色为暗房")
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink2)
                HStack(spacing: 24) {
                    appearanceSwatch(color: swatchLight, name: "白昼放映厅")
                    appearanceSwatch(color: swatchDark, name: "暗房")
                }
            }
        }
    }

    /// 色样展示：固定色值（#F5F4F0 / #0D0E11，仅作预览，不随外观切换）
    private let swatchLight = Color(red: 0xF5 / 255.0, green: 0xF4 / 255.0, blue: 0xF0 / 255.0)
    private let swatchDark = Color(red: 0x0D / 255.0, green: 0x0E / 255.0, blue: 0x11 / 255.0)

    private func appearanceSwatch(color: Color, name: String) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .frame(width: 56, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.rule, lineWidth: 1)
                )
            Text(name)
                .font(.system(size: 11))
                .foregroundStyle(Theme.ink3)
        }
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
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.0"
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