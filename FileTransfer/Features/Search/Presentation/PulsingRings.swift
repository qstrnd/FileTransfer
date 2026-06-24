import SwiftUI

struct PulsingRings: View {
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
