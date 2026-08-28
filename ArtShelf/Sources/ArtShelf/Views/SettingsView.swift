import SwiftUI
import AppKit

struct SettingsView: View {

    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 顶栏 Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("偏好设置")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(ArtShelfStyle.ink)

                    Text("自定义 ArtShelf 的外观色彩与程序坞图标")
                        .font(.system(size: 12))
                        .foregroundStyle(ArtShelfStyle.inkSecondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(ArtShelfStyle.inkTertiary)
                }
                .buttonStyle(.plain)
                .help("关闭 (Esc)")
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 16)

            Divider()
                .foregroundStyle(ArtShelfStyle.rule)

            // 内容区域
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {

                    // SECTION 1: 外观模式
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "circle.righthalf.filled")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ArtShelfStyle.accent)
                            Text("外观模式")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(ArtShelfStyle.ink)
                        }

                        HStack(spacing: 12) {
                            ForEach(AppAppearance.allCases) { item in
                                appearanceCard(item)
                            }
                        }
                    }

                    // SECTION 2: 应用图标
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "app.dashed")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ArtShelfStyle.accent)
                            Text("应用图标")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(ArtShelfStyle.ink)
                            Spacer()
                            Text("点击即刻切换 Dock 栏图标")
                                .font(.system(size: 11))
                                .foregroundStyle(ArtShelfStyle.inkTertiary)
                        }

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(AppIconOption.allCases) { icon in
                                iconCard(icon)
                            }
                        }
                    }

                    // SECTION 3: 数据与关于
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ArtShelfStyle.accent)
                            Text("关于与存储")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(ArtShelfStyle.ink)
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ArtShelf 本地媒体库")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(ArtShelfStyle.ink)
                                Text("~/Library/Application Support/ArtShelf/library.json")
                                    .font(.system(size: 11).monospaced())
                                    .foregroundStyle(ArtShelfStyle.inkTertiary)
                            }

                            Spacer()

                            Button {
                                let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                                let folder = appSupport.appendingPathComponent("ArtShelf")
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path)
                            } label: {
                                Text("在访达中显示")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(ArtShelfStyle.well)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(ArtShelfStyle.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(ArtShelfStyle.rule, lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 620, height: 600)
        .background(ArtShelfStyle.paper)
    }

    // MARK: - 外观卡片
    @ViewBuilder
    private func appearanceCard(_ item: AppAppearance) -> some View {
        let isSelected = themeManager.appearance == item

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                themeManager.appearance = item
            }
        } label: {
            VStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(isSelected ? ArtShelfStyle.accent.opacity(0.12) : ArtShelfStyle.well)
                        .frame(width: 44, height: 44)

                    Image(systemName: item.iconName)
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? ArtShelfStyle.accent : ArtShelfStyle.inkSecondary)
                }

                Text(item.title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? ArtShelfStyle.accent : ArtShelfStyle.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? ArtShelfStyle.accentWash : ArtShelfStyle.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? ArtShelfStyle.accent : ArtShelfStyle.rule, lineWidth: isSelected ? 1.5 : 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 图标卡片
    @ViewBuilder
    private func iconCard(_ icon: AppIconOption) -> some View {
        let isSelected = themeManager.selectedIcon == icon

        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                themeManager.selectedIcon = icon
            }
        } label: {
            HStack(spacing: 12) {
                // 图标微缩预览图
                Group {
                    if let nsImg = icon.image {
                        Image(nsImage: nsImg)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ArtShelfStyle.well)
                    }
                }
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(icon.title)
                            .font(.system(size: 12.5, weight: isSelected ? .bold : .semibold))
                            .foregroundStyle(isSelected ? ArtShelfStyle.accent : ArtShelfStyle.ink)

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(ArtShelfStyle.accent)
                        }
                    }

                    Text(icon.subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(ArtShelfStyle.inkSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isSelected ? ArtShelfStyle.accentWash : ArtShelfStyle.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(isSelected ? ArtShelfStyle.accent : ArtShelfStyle.rule, lineWidth: isSelected ? 1.5 : 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
