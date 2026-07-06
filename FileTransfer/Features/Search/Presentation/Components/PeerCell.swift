import SwiftUI

// MARK: - PeerCell

struct PeerCell: View {
    let peer: Peer
    let state: PeerConnectionState
    let onTap: () -> Void
    var size: CGFloat = 100

    // Both are driven by local state so they can fade independently
    // of the PeerConnectionState value — the cell stays in .rejected
    // visually for as long as the fade takes, even after state → .idle.
    @State private var lockOpacity: Double = 0
    @State private var rejectedRingOpacity: Double = 0

    private let ringLineWidth: CGFloat = 3
    private let rejectedFadeDuration: TimeInterval = 0.5

    private var emojiSize: CGFloat { size * 0.44 }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.avatarBubbleBackground)
                        .frame(width: size, height: size)
                        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 2)

                    Text(peer.emojiComponent)
                        .font(.system(size: emojiSize))

                    // Lock icon — always in the hierarchy so opacity can animate
                    // freely; only visible when lockOpacity > 0.
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Color.red.opacity(0.85), in: Circle())
                        .opacity(lockOpacity)

                    // Active-state rings — each embeds its own transition animation
                    // so the ZStack needs no implicit .animation(value:) modifier.
                    // This keeps rejectedRingOpacity / lockOpacity free to animate
                    // at their own duration via withAnimation in onChange.
                    if state == .connecting {
                        SpinnerRing(diameter: size - ringLineWidth)
                            .transition(.opacity.animation(.easeInOut(duration: 0.35)))
                    } else if state == .connected {
                        Circle()
                            .strokeBorder(Color.accentColor, lineWidth: ringLineWidth)
                            .frame(width: size, height: size)
                            .transition(.opacity.animation(.easeInOut(duration: 0.35)))
                    }

                    // Rejected ring — opacity-driven; animates via withAnimation
                    // in onChange so it's unaffected by any implicit animation.
                    Circle()
                        .strokeBorder(Color.red.opacity(0.7), lineWidth: 2)
                        .frame(width: size, height: size)
                        .opacity(rejectedRingOpacity)
                }
                .overlay(alignment: .topLeading) {
                    if state == .connected {
                        disconnectBadge
                            .offset(x: -4, y: -4)
                            .transition(
                                .scale(scale: 0.5).combined(with: .opacity)
                                .animation(.spring(duration: 0.3))
                            )
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
        .onChange(of: state) { old, new in
            switch new {
            case .rejected:
                playRejectedAnimation()  // handles ring + lock fade-in
            default:
                if old == .rejected {
                    // Defer past the ViewModel's withAnimation(.spring) transaction
                    // that triggered this state change. Without the Task, onChange
                    // fires synchronously inside that transaction and the spring
                    // animation wins over withAnimation(.easeOut) here.
                    Task { @MainActor in
                        withAnimation(.easeOut(duration: rejectedFadeDuration)) {
                            rejectedRingOpacity = 0
                            lockOpacity = 0
                        }
                    }
                }
            }
        }
    }

    // MARK: - Disconnect badge

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
        .frame(width: 36, height: 36)
    }

    // MARK: - Animations

    private func playRejectedAnimation() {
        withAnimation(.easeIn(duration: 0.15)) { rejectedRingOpacity = 1 }
        withAnimation(.easeIn(duration: 0.2).delay(0.1)) { lockOpacity = 1 }
        // Fade-out is handled by onChange(of: state) when state → .idle,
        // so ring and lock disappear together over rejectedFadeDuration.
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
