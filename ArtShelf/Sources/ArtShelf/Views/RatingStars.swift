import SwiftUI

/// 交互式星级评分
struct RatingStars: View {

    let rating: Int
    let onRate: ((Int) -> Void)?

    @State private var hoverRating: Int = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= currentRating ? "star.fill" : "star")
                    .font(.system(size: 13, weight: .medium))
                    // 未选中的星用发丝线色，几乎隐于纸面；选中的才落朱砂
                    .foregroundStyle(star <= currentRating ? ArtShelfStyle.accent : ArtShelfStyle.inkTertiary.opacity(0.35))
                    .onHover { hovering in
                        if onRate != nil {
                            hoverRating = hovering ? star : 0
                        }
                    }
                    .onTapGesture {
                        onRate?(star == rating ? 0 : star)
                    }
            }
        }
        .help(rating > 0 ? "评分: \(rating)/5" : "点击设置评分")
    }

    private var currentRating: Int {
        hoverRating > 0 ? hoverRating : rating
    }
}
