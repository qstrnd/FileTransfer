import SwiftUI

struct SearchView: View {
    var viewModel: SearchViewModel
    var namespace: Namespace.ID

    @State private var showRings = false
    @State private var showText = false
    @State private var showDataExchange = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                heroSection
                    .padding(.top, 100)
                    .zIndex(1)

                // Content area always fills remaining space so the VStack height
                // equals the full screen height from the very first render frame,
                // keeping the hero circle at a stable position throughout.
                ZStack {
                    if viewModel.discoveredPeers.isEmpty {
                        if showText {
                            VStack {
                                Spacer()
                                SearchingText()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 24)
                                Spacer()
                                Spacer()
                            }
                            .transition(.opacity)
                        }
                    } else {
                        peerScrollSection
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.35), value: viewModel.discoveredPeers.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                if viewModel.hasConnectedPeers {
                    sendButton
                } else if !viewModel.discoveredPeers.isEmpty {
                    hintText
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(duration: 0.35), value: viewModel.hasConnectedPeers)
            .animation(.easeInOut(duration: 0.35), value: viewModel.discoveredPeers.isEmpty)
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

    // MARK: - Hero

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
                .matchedGeometryEffect(id: "heroCircle", in: namespace, isSource: false)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Peer grid

    private var peerScrollSection: some View {
        ZStack(alignment: .top) {
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

    // MARK: - Bottom bar

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

    private var hintText: some View {
        Text("Tap on a device to establish connection")
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            .padding(.bottom, 28)
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
    makePeer("🦙 Happy Llama"),    makePeer("🦒 Cunning Giraffe"),
    makePeer("🐺 Puffy Wolf"),     makePeer("🐱 Sly Cat"),
    makePeer("🦅 Swift Eagle"),    makePeer("🦋 Vivid Butterfly"),
    makePeer("🌟 Radiant Star"),   makePeer("🌊 Crashing Wave"),
    makePeer("🌙 Crescent Moon"),  makePeer("☄️ Blazing Comet"),
    makePeer("🌺 Cherry Blossom"), makePeer("🦩 Pink Flamingo"),
    makePeer("🐙 Inky Octopus"),   makePeer("🦈 Silent Shark"),
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

#Preview("State: connected") {
    @Previewable @Namespace var ns
    let p0 = samplePeers[0]; let p1 = samplePeers[1]
    SearchView(viewModel: previewVM(peers: [p0, p1, samplePeers[2], samplePeers[3]],
                                    states: [p0: .connected, p1: .connected]), namespace: ns)
}

#Preview("State: rejected") {
    @Previewable @Namespace var ns
    let p = samplePeers[0]
    SearchView(viewModel: previewVM(peers: [p, samplePeers[1]], states: [p: .rejected]), namespace: ns)
}

#endif
