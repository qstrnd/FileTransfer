import SwiftUI

struct SearchView: View {
    var viewModel: SearchViewModel
    var namespace: Namespace.ID

    @State private var showRings = false
    @State private var showText = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 100)

                // Hero circle — rings overflow its bounds visually
                ZStack {
                    if showRings {
                        PulsingRings()
                            .transition(.opacity)
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
                        .matchedGeometryEffect(id: "heroCircle", in: namespace)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if showText {
                    Text("Searching\nfor other devices\non the network...")
                        .font(.system(size: 30, weight: .bold))
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .shimmer()
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                }

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            viewModel.start()
            withAnimation(.easeIn(duration: 0.5).delay(0.25)) { showRings = true }
            withAnimation(.easeIn(duration: 0.4).delay(0.45)) { showText = true }
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}

// MARK: - Pulsing rings

private struct PulsingRings: View {
    @State private var animating = false
    private let diameter: CGFloat = 128

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(red: 0.53, green: 0.71, blue: 0.96).opacity(0.25))
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(animating ? 2.7 : 1)
                    .opacity(animating ? 0 : 1)
                    .animation(
                        .easeOut(duration: 2.0)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.65),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

// MARK: - Shimmer

private extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -0.4

    func body(content: Content) -> some View {
        content.overlay {
            LinearGradient(
                stops: [
                    .init(color: .clear,                  location: phase - 0.15),
                    .init(color: .white.opacity(0.55),    location: phase),
                    .init(color: .clear,                  location: phase + 0.15),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .mask(content)
            .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                phase = 1.4
            }
        }
    }
}

#Preview {
    @Previewable @Namespace var ns
    SearchView(
        viewModel: SearchViewModel(
            emoji: "🐟",
            name: "Fantastic Fish",
            service: MultipeerNearbyService(),
            onBack: {}
        ),
        namespace: ns
    )
}
