import SwiftUI

// MARK: - PeerCell

struct PeerCell: View {
    let peer: Peer
    let state: PeerConnectionState
    let onTap: () -> Void

    @State private var shakeOffset: CGFloat = 0
    @State private var lockOpacity: Double = 0

    private let circleSize: CGFloat = 100
    private let ringLineWidth: CGFloat = 3

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: circleSize, height: circleSize)
                        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 2)

                    Text(peer.emojiComponent)
                        .font(.system(size: 44))

                    if state == .rejected {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Color.red.opacity(0.85), in: Circle())
                            .opacity(lockOpacity)
                    }

                    // Rings — inline if/else so SwiftUI can apply .transition(.opacity)
                    // when states enter or leave, giving smooth fade-in/out.
                    if state == .connecting {
                        SpinnerRing(diameter: circleSize - ringLineWidth)
                            .transition(.opacity)
                    } else if state == .connected {
                        Circle()
                            .strokeBorder(Color.accentColor, lineWidth: ringLineWidth)
                            .frame(width: circleSize, height: circleSize)
                            .transition(.opacity)
                    } else if state == .rejected {
                        Circle()
                            .strokeBorder(Color.red.opacity(0.7), lineWidth: 2)
                            .frame(width: circleSize, height: circleSize)
                            .transition(.opacity)
                    }
                }
                // Implicit animation on all state-driven view changes within the ZStack,
                // including ring insert/remove transitions. Ensures the rejected ring
                // fades out even when the state change arrives from an async Task where
                // the withAnimation context has already exited.
                .animation(.easeInOut(duration: 0.4), value: state)
                .offset(x: shakeOffset)
                // Badge overlay: positioned outside the ZStack frame, does not
                // affect the cell's layout size or sibling positions.
                .overlay(alignment: .topLeading) {
                    if state == .connected {
                        disconnectBadge
                            // Shift so the badge straddles the top-left edge of the circle.
                            .offset(x: -4, y: -4)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }
                }

                Text(peer.nameComponent)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .disabled(state == .connecting)
        .onChange(of: state) { _, new in
            if new == .rejected { playRejectedAnimation() }
        }
    }

    // MARK: - Disconnect badge

    /// iOS home-screen style minus badge. Tap area is 36×36 so it's easy to hit;
    /// the visual circle is 26 pt, centred within the larger tap region.
    private var disconnectBadge: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 26, height: 26)
                    .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        // 36×36 frame creates the hit area without growing the badge visually.
        .frame(width: 36, height: 36)
    }

    // MARK: - Animations

    private func playRejectedAnimation() {
        Task {
            let offsets: [CGFloat] = [10, -10, 8, -8, 5, -5, 0]
            for offset in offsets {
                withAnimation(.linear(duration: 0.055)) { shakeOffset = offset }
                try? await Task.sleep(for: .milliseconds(55))
            }
            shakeOffset = 0
            withAnimation(.easeIn(duration: 0.2)) { lockOpacity = 1 }
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.35)) { lockOpacity = 0 }
        }
    }
}

// MARK: - SpinnerRing

private struct SpinnerRing: View {
    let diameter: CGFloat
    private let lineWidth: CGFloat = 3
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(Color.accentColor.opacity(0.6),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: diameter, height: diameter)
            .rotationEffect(.degrees(rotation - 90))
            .onAppear {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}
