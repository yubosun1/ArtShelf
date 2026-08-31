import SwiftUI

/// 状态胶囊徽标（已看 / 在看 62% / 待看 …）
struct StatusBadge: View {

    let status: MediaStatus
    let type: MediaType
    /// 自定义文案（如「在看 62%」），nil 时用状态默认文案
    var text: String? = nil

    var body: some View {
        let colors = Theme.statusColors(status)
        Text(text ?? status.label(for: type))
            .font(.system(size: 9.5, weight: .bold))
            .tracking(0.5)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(colors.bg)
            .foregroundStyle(colors.tx)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
