import SwiftUI

/// 评分星标：只读展示或可编辑两种模式
struct RatingStars: View {

    let rating: Int
    var size: CGFloat = 13
    var onRate: ((Int) -> Void)? = nil   // 非 nil 时可点击打分

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { star in
                let filled = star <= rating
                let starView = Image(systemName: filled ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(filled ? Theme.amber : Theme.ink3.opacity(0.5))
                if let onRate {
                    // 可点态：扩大热区；再点一次当前星级 = 清零
                    starView
                        .contentShape(Rectangle().inset(by: -6))
                        .onTapGesture { onRate(star == rating ? 0 : star) }
                } else {
                    // 只读态不挂任何手势
                    starView
                }
            }
        }
    }
}
