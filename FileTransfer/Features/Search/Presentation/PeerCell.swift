import SwiftUI

// MARK: - PeerCell

struct PeerCell: View {
    let peer: Peer
    let state: PeerConnectionState
    let onTap: () -> Void

    @State private var shakeOffset: CGFloat = 0
    @State private var lockOpacity: Double = 0

    private let circleSize: CGFloat = 100
    private let ringSize: CGFloat = 118

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack {
                    stateRing
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
                    }
                    .offset(x: shakeOffset)
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

    @ViewBuilder
    private var stateRing: some View {
        switch state {
        case .idle:
            EmptyView()
        case .connecting:
            SpinnerRing(diameter: ringSize)
        case .connected:
            Circle()
                .stroke(Color.accentColor, lineWidth: 3)
                .frame(width: ringSize, height: ringSize)
        case .rejected:
            Circle()
                .stroke(Color.red.opacity(0.4), lineWidth: 2)
                .frame(width: ringSize, height: ringSize)
        }
    }

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
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(Color.accentColor.opacity(0.6),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: diameter, height: diameter)
            .rotationEffect(.degrees(rotation - 90))
            .onAppear {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}
