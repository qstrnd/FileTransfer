import SwiftUI

struct SearchHeroSection: View {
    var viewModel: SearchViewModel
    var namespace: Namespace.ID
    var showRings: Bool

    var body: some View {
        ZStack {
            if showRings {
                PulsingRings().transition(.opacity)
            }
            Button { viewModel.goBack() } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 128, height: 128)
                        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 2)
                    Text(viewModel.emoji)
                        .font(.system(size: 64))
                }
                .matchedGeometryEffect(id: "heroCircle", in: namespace, isSource: false)
            }
            .buttonStyle(.plain)
        }
    }
}
