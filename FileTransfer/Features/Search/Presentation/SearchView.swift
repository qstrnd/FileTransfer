import SwiftUI

struct SearchView: View {
    var viewModel: SearchViewModel
    var namespace: Namespace.ID

    @State private var showRings = false
    @State private var showText = false
    @State private var showDataExchange = false
    @State private var showTextShare = false
    @State private var showMediaPicker = false
    @State private var showContactPicker = false
    @State private var didBackground = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                SearchHeroSection(viewModel: viewModel, namespace: namespace, showRings: showRings)
                    .padding(.top, 60)
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
                        SearchPeerGrid(viewModel: viewModel)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.35), value: viewModel.discoveredPeers.isEmpty)
            }
        }
        .overlay {
            TransferCurtainView(
                viewModel: viewModel,
                onShareText:     { showTextShare = true },
                onSharePhoto:    { showMediaPicker = true },
                onShareDocument: { showDataExchange = true },
                onShareContact:  { showContactPicker = true }
            )
            .ignoresSafeArea()
        }
        .background(PinnedToast(peer: viewModel.disconnectedPeer))
        .background(PinnedToast(peer: viewModel.reconnectedPeer, message: "is connected"))
        .background(PinnedToast(peer: nil, staticMessage: viewModel.connectionsRestored ? "Connections are restored" : nil))
        .background(PinnedWindow(
            content: InvitationAlert(
                peer: viewModel.pendingInvitationFrom,
                onAccept: { viewModel.acceptInvitation() },
                onDecline: { viewModel.declineInvitation() }
            ),
            isVisible: viewModel.pendingInvitationFrom != nil,
            isInteractive: true,
            hideDelay: 0.45
        ))
        .background(PinnedWindow(
            content: ReceivedTextAlert(
                message: viewModel.receivedMessage,
                onDismiss: { viewModel.receivedMessage = nil }
            ),
            isVisible: viewModel.receivedMessage != nil,
            isInteractive: true,
            hideDelay: 0.2
        ))
        .background(PinnedReceivingToast(transfer: viewModel.receivingMediaTransfer))
        .background(PinnedWindow(
            content: ReceivedMediaAlert(
                transfer: viewModel.receivedMedia,
                thumbnailGate: viewModel.thumbnailGate,
                onDismiss: { viewModel.receivedMedia = nil },
                onSaveToGallery: { await viewModel.mediaSavingGate.saveToGallery($0) },
                onSaveToFiles:   { viewModel.mediaSavingGate.saveToFiles($0) },
                onShare:         { viewModel.mediaSavingGate.share($0) }
            ),
            isVisible: viewModel.receivedMedia != nil,
            isInteractive: true,
            hideDelay: 0.2
        ))
        .background(PinnedWindow(
            content: SendingTransferAlert(
                transfer: viewModel.outgoingMediaTransfer?.sendingStatus,
                onAbort: { viewModel.abortMediaTransfer() }
            ),
            isVisible: viewModel.outgoingMediaTransfer != nil,
            isInteractive: viewModel.outgoingMediaTransfer != nil,
            hideDelay: 0.45
        ))
        .background(PinnedWindow(
            content: SendingTransferAlert(
                transfer: viewModel.outgoingContactTransfer?.sendingStatus,
                onAbort: { viewModel.abortContactTransfer() }
            ),
            isVisible: viewModel.outgoingContactTransfer != nil,
            isInteractive: viewModel.outgoingContactTransfer != nil,
            hideDelay: 0.45
        ))
        .background(PinnedWindow(
            content: ReceivedContactAlert(
                transfer: viewModel.receivedContact,
                onDismiss: { viewModel.receivedContact = nil },
                onShare: { data in viewModel.shareReceivedContact(vCardData: data) }
            ),
            isVisible: viewModel.receivedContact != nil,
            isInteractive: true,
            hideDelay: 0.2
        ))
        .sheet(isPresented: $showTextShare) {
            TextShareView(
                onSend: { text in
                    viewModel.sendText(text)
                    showTextShare = false
                },
                onCancel: { showTextShare = false },
                hasConnections: !viewModel.connectedPeers.isEmpty
            )
        }
        .fullScreenCover(isPresented: $showMediaPicker) {
            MediaPickerView(
                onComplete: { items in
                    showMediaPicker = false
                    viewModel.sendMedia(items)
                },
                onCancel: { showMediaPicker = false }
            )
        }
        .fullScreenCover(isPresented: $showDataExchange) {
            DataExchangeView()
        }
        .fullScreenCover(isPresented: $showContactPicker) {
            ContactPickerView(
                onComplete: { contacts in
                    showContactPicker = false
                    if !contacts.isEmpty { viewModel.sendContacts(contacts) }
                },
                onCancel: { showContactPicker = false }
            )
            .ignoresSafeArea()
        }
        .onAppear {
            viewModel.start()
            withAnimation(.easeIn(duration: 0.5).delay(0.25)) { showRings = true }
            withAnimation(.easeIn(duration: 0.4).delay(0.45)) { showText = true }
        }
        .onDisappear { viewModel.stop() }
        .onChange(of: scenePhase) { _, new in
            switch new {
            case .background:
                // Remember that we went to background so we can act on return.
                // scenePhase never jumps directly background→active; it passes
                // through .inactive, so old==.background never holds on .active.
                didBackground = true
                // Stop the service immediately so connected peers receive a
                // .notConnected callback right away instead of waiting for timeout.
                viewModel.handleBackground()

            case .active where didBackground:
                didBackground = false
                // 1. Invalidate connections and restart discovery.
                viewModel.handleForeground()
                // 2. Restart entry animations: remove the views first so their
                //    @State resets and onAppear fires again on re-insertion.
                showRings = false
                showText  = false
                withAnimation(.easeIn(duration: 0.5).delay(0.25)) { showRings = true }
                withAnimation(.easeIn(duration: 0.4).delay(0.45)) { showText  = true }

            default:
                break
            }
        }
    }
}

// MARK: - Previews

#if DEBUG

@MainActor
private final class PreviewNearbyService: NearbySessionService {
    var delegate: (any NearbySessionServiceDelegate)?
    func start(displayName: String, deviceID: UUID) {}
    func stop() {}
    func connect(to peer: Peer, isReconnect: Bool) {}
    func send(text: String, to peer: Peer) {}
    func acceptInvitation() {}
    func declineInvitation() {}
}

private func makePeer(_ name: String) -> Peer { Peer(displayName: name) }

private func previewVM(peers: [Peer], states: [Peer: PeerConnectionState] = [:]) -> SearchViewModel {
    let vm = SearchViewModel(emoji: "🐟", name: "Fantastic Fish", deviceID: UUID(),
                             service: PreviewNearbyService(),
                             connectionHistory: InMemoryConnectionHistoryStore(),
                             historyStore: .preview,
                             onBack: {})
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
