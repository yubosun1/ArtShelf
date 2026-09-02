import SwiftUI

/// 库页氛围光：以类型代表色投下大半径淡光晕，向四周自然散尽
///
/// 用于库页页头（配合全页基调 wash 与 Hero 整页氛围场同属一套暗房光语），
/// 避免页头后方大片纯色与光晕区硬切。强度随外观变化（暗房更亮、白昼更淡），
/// 口径对齐 `Theme.ambientOpacity`。光晕以自身 frame 中心为圆心，
/// 尺寸与落位由使用处通过 frame / offset 决定。
struct AmbientGlow: View {

    let color: Color
    /// 光晕半径（点）：库页页头取大半径铺开，分节标题取小半径聚焦
    var radius: CGFloat = 260

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        RadialGradient(
            colors: [
                color.opacity(0.24),
                color.opacity(0.10),
                .clear
            ],
            center: .center,
            startRadius: 8,
            endRadius: radius
        )
        .opacity(Theme.ambientOpacity(scheme))
        .allowsHitTesting(false)
    }
}

extension MediaType {
    /// 类型代表色（转发 Theme 令牌：影视蓝 / 音乐琥珀 / 书籍绿）
    var accentColor: Color {
        switch self {
        case .movie: return Theme.typeMovie
        case .music: return Theme.typeMusic
        case .book:  return Theme.typeBook
        }
    }
}
