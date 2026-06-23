import SwiftUI

// MARK: - SearchView

struct SearchView: View {
    var viewModel: SearchViewModel
    var namespace: Namespace.ID

    @State private var showRings = false
    @State private var showText = false
    @State private var showDataExchange = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                heroSection
                    .padding(.top, 100)
                    .zIndex(1)

                if viewModel.discoveredPeers.isEmpty {
                    if showText {
                        Spacer()
                        searchingTextView
                            .padding(.horizontal, 24)
                            .transition(.opacity)
                        Spacer()
                        Spacer()
                    }
                } else {
                    peerScrollSection
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: viewModel.discoveredPeers.isEmpty)
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.hasConnectedPeers {
                sendButton
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(duration: 0.35), value: viewModel.hasConnectedPeers)
            }
        }
        .alert(
            "Connection Request",
            isPresented: Binding(
                get: { viewModel.pendingInvitationFrom != nil },
                set: { if !$0 { viewModel.declineInvitation() } }
            ),
            presenting: viewModel.pendingInvitationFrom
        ) { peer in
            Button("Accept") { viewModel.acceptInvitation() }
            Button("Decline", role: .destructive) { viewModel.declineInvitation() }
        } message: { peer in
            Text("\(peer.nameComponent) wants to connect")
        }
        .fullScreenCover(isPresented: $showDataExchange) {
            DataExchangeView()
        }
        .onAppear {
            viewModel.start()
            withAnimation(.easeIn(duration: 0.5).delay(0.25)) { showRings = true }
            withAnimation(.easeIn(duration: 0.4).delay(0.45)) { showText = true }
        }
        .onDisappear { viewModel.stop() }
    }

    // MARK: Hero

    private var heroSection: some View {
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
                .matchedGeometryEffect(id: "heroCircle", in: namespace)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Searching text

    private var searchingTextView: some View {
        SearchingText()
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Peer grid

    private var peerScrollSection: some View {
        ZStack(alignment: .top) {
            // Gradient first → behind scroll content so peer circles render on top of it.
            LinearGradient(
                stops: [
                    .init(color: Color(.systemGroupedBackground),               location: 0.00),
                    .init(color: Color(.systemGroupedBackground).opacity(0.85), location: 0.25),
                    .init(color: Color(.systemGroupedBackground).opacity(0.55), location: 0.55),
                    .init(color: Color(.systemGroupedBackground).opacity(0.15), location: 0.80),
                    .init(color: .clear,                                         location: 1.00),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)
            .allowsHitTesting(false)

            // ScrollView second → peer circles render on top of the gradient above
            ScrollView {
                LazyVStack(spacing: 32) {
                    ForEach(viewModel.peerRows, id: \.first?.id) { row in
                        peerRowView(row)
                    }
                }
                .padding(.top, 160)
                .padding(.bottom, 40)
            }
        }
    }

    private func peerRowView(_ row: [Peer]) -> some View {
        HStack(spacing: 0) {
            if row.count == 1 {
                Spacer()
                peerCell(row[0])
                Spacer()
            } else {
                peerCell(row[0]).frame(maxWidth: .infinity)
                peerCell(row[1]).frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
    }

    private func peerCell(_ peer: Peer) -> some View {
        PeerCell(
            peer: peer,
            state: viewModel.peerStates[peer] ?? .idle,
            onTap: { viewModel.connect(to: peer) }
        )
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    // MARK: Send button

    private var sendButton: some View {
        let count = viewModel.connectedPeers.count
        return Button { showDataExchange = true } label: {
            Text("Send to \(count) device\(count == 1 ? "" : "s")")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}

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
        .disabled(state == .connecting || state == .connected)
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
            // Shake: 7 steps of alternating offsets, 55 ms each
            let offsets: [CGFloat] = [10, -10, 8, -8, 5, -5, 0]
            for offset in offsets {
                withAnimation(.linear(duration: 0.055)) { shakeOffset = offset }
                try? await Task.sleep(for: .milliseconds(55))
            }
            shakeOffset = 0

            // Lock icon: fade in, hold, fade out
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

// MARK: - Searching text with shimmer

private struct SearchingText: View {
    @State private var phase: CGFloat = -0.3

    var body: some View {
        Text("Searching\nfor other devices\non the network...")
            .font(.system(size: 30, weight: .bold))
            .multilineTextAlignment(.leading)
            // Gradient applied directly as the text colour so the shimmer is
            // visible only through the text glyphs — no mask layer needed.
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: Color.secondary,          location: max(0, phase - 0.25)),
                        .init(color: Color(white: 0.72),       location: phase),
                        .init(color: Color.secondary,          location: min(1, phase + 0.25)),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
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
                    .init(color: .clear,               location: phase - 0.15),
                    .init(color: .white.opacity(0.55), location: phase),
                    .init(color: .clear,               location: phase + 0.15),
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

// MARK: - ViewModel helper

extension SearchViewModel {
    // Peers split into rows of 2; odd final peer gets its own row (centered by the caller).
    var peerRows: [[Peer]] {
        stride(from: 0, to: discoveredPeers.count, by: 2).map { i in
            Array(discoveredPeers[i..<min(i + 2, discoveredPeers.count)])
        }
    }
}

// MARK: - Previews

#if DEBUG

@MainActor
private final class PreviewNearbyService: NearbySessionService {
    var delegate: (any NearbySessionServiceDelegate)?
    func start(displayName: String) {}
    func stop() {}
    func connect(to peer: Peer) {}
    func send(text: String, to peer: Peer) {}
    func acceptInvitation() {}
    func declineInvitation() {}
}

private func makePeer(_ name: String) -> Peer { Peer(displayName: name) }

private func previewVM(peers: [Peer], states: [Peer: PeerConnectionState] = [:]) -> SearchViewModel {
    let vm = SearchViewModel(emoji: "🐟", name: "Fantastic Fish",
                             service: PreviewNearbyService(), onBack: {})
    vm.discoveredPeers = peers
    vm.peerStates = states
    return vm
}

private let samplePeers: [Peer] = [
    makePeer("🦙 Happy Llama"),
    makePeer("🦒 Cunning Giraffe"),
    makePeer("🐺 Puffy Wolf"),
    makePeer("🐱 Sly Cat"),
    makePeer("🦅 Swift Eagle"),
    makePeer("🦋 Vivid Butterfly"),
    makePeer("🌟 Radiant Star"),
    makePeer("🌊 Crashing Wave"),
    makePeer("🌙 Crescent Moon"),
    makePeer("☄️ Blazing Comet"),
    makePeer("🌺 Cherry Blossom"),
    makePeer("🦩 Pink Flamingo"),
    makePeer("🐙 Inky Octopus"),
    makePeer("🦈 Silent Shark"),
    makePeer("🌵 Desert Cactus"),
]

#Preview("Searching — no peers") {
    @Previewable @Namespace var ns
    SearchView(viewModel: previewVM(peers: []), namespace: ns)
}

#Preview("1 peer") {
    @Previewable @Namespace var ns
    SearchView(viewModel: previewVM(peers: Array(samplePeers.prefix(1))), namespace: ns)
}

#Preview("2 peers") {
    @Previewable @Namespace var ns
    SearchView(viewModel: previewVM(peers: Array(samplePeers.prefix(2))), namespace: ns)
}

#Preview("3 peers") {
    @Previewable @Namespace var ns
    SearchView(viewModel: previewVM(peers: Array(samplePeers.prefix(3))), namespace: ns)
}

#Preview("4 peers") {
    @Previewable @Namespace var ns
    SearchView(viewModel: previewVM(peers: Array(samplePeers.prefix(4))), namespace: ns)
}

#Preview("5 peers") {
    @Previewable @Namespace var ns
    SearchView(viewModel: previewVM(peers: Array(samplePeers.prefix(5))), namespace: ns)
}

#Preview("15 peers (scroll)") {
    @Previewable @Namespace var ns
    SearchView(viewModel: previewVM(peers: samplePeers), namespace: ns)
}

#Preview("State: connecting") {
    @Previewable @Namespace var ns
    let p = samplePeers[0]
    SearchView(viewModel: previewVM(peers: [p, samplePeers[1]], states: [p: .connecting]), namespace: ns)
}

#Preview("State: connected (with send button)") {
    @Previewable @Namespace var ns
    let p0 = samplePeers[0]
    let p1 = samplePeers[1]
    SearchView(viewModel: previewVM(peers: [p0, p1, samplePeers[2], samplePeers[3]],
                                    states: [p0: .connected, p1: .connected]), namespace: ns)
}

#Preview("State: rejected") {
    @Previewable @Namespace var ns
    let p = samplePeers[0]
    SearchView(viewModel: previewVM(peers: [p, samplePeers[1]], states: [p: .rejected]), namespace: ns)
}

#endif
