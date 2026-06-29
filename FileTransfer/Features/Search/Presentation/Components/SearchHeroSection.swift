import SwiftUI

struct SearchHeroSection: View {
    var viewModel: SearchViewModel
    var namespace: Namespace.ID
    var showRings: Bool
    var compact: Bool = false

    private var circleSize: CGFloat { compact ? 72 : 128 }
    private var emojiSize: CGFloat { compact ? 36 : 64 }

    var body: some View {
        ZStack {
            if !compact && showRings {
                PulsingRings().transition(.opacity)
            }
            Button { viewModel.goBack() } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: circleSize, height: circleSize)
                        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 2)
                    Text(viewModel.emoji)
                        .font(.system(size: emojiSize))
                }
                .matchedGeometryEffect(id: "heroCircle", in: namespace, isSource: false)
            }
            .buttonStyle(.plain)
        }
    }
}
