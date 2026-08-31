import SwiftUI

/// 评分星标：只读展示或可编辑两种模式
struct RatingStars: View {

    let rating: Int
    var size: CGFloat = 13
    var onRate: ((Int) -> Void)? = nil   // 非 nil 时可点击打分

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(star <= rating ? Theme.amber : Theme.ink3.opacity(0.5))
                    .onTapGesture {
                        // 再点一次当前星级 = 清零
                        onRate?(star == rating ? 0 : star)
                    }
            }
        }
    }
}
