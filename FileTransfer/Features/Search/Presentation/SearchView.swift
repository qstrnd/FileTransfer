import SwiftUI

struct SearchView: View {
    var viewModel: SearchViewModel
    var namespace: Namespace.ID

    @State private var showRings = false
    @State private var showText = false
    @State private var showFilePicker = false
    @State private var showTextShare = false
    @State private var showMediaPicker = false
    @State private var showContactPicker = false
    @State private var didBackground = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let isIPad = horizontalSizeClass == .regular
            // iPad landscape: ~44% of landscape width (similar to 2/3 of portrait height).
            // iPhone landscape: capped at 340 using portrait height reference.
            let curtainPanelWidth: CGFloat = isIPad
                ? min(geo.size.width * 0.44, 560)
                : min(geo.size.height * 0.85, 340)
            let curtainRightMargin: CGFloat = 16
            let leftWidth: CGFloat = geo.size.width - curtainPanelWidth - curtainRightMargin
            // Portrait iPad: centre the sheet at 2/3 of portrait width; iPhone full-width.
            let portraitMaxSheetWidth: CGFloat? = isIPad
                ? min(geo.size.width * (2.0 / 3.0), 620)
                : nil

            if isLandscape {
                landscapeLayout(leftWidth: leftWidth,
                                curtainPanelWidth: curtainPanelWidth,
                                curtainRightMargin: curtainRightMargin)
            } else {
                portraitLayout(maxSheetWidth: portraitMaxSheetWidth)
            }
        }
        .background(ToastHost())
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
                onDismiss: { viewModel.receivedMessage = nil },
                onCopied: { ToastCenter.shared.show { CopiedToast() } }
            ),
            isVisible: viewModel.receivedMessage != nil,
            isInteractive: true,
            hideDelay: 0.2,
            // The text-selection edit menu (Copy/Look Up/…) always targets the
            // scene's key window — without this it renders behind this overlay.
            becomesKey: true
        ))
        .onChange(of: viewModel.receivingMediaTransfer?.receivingProgress
                      ?? viewModel.receivingFileTransfer?.receivingProgress) { _, progress in
            if let progress {
                ToastCenter.shared.show(id: "receivingProgress", duration: nil) {
                    ReceivingToastCapsule(progress: progress)
                }
            } else {
                ToastCenter.shared.hide(id: "receivingProgress")
            }
        }
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
            content: ReceivedFileAlert(
                transfer: viewModel.receivedFiles,
                thumbnailGate: viewModel.historyThumbnailGate,
                onDismiss: { viewModel.receivedFiles = nil },
                onSaveToFiles: { viewModel.fileSaveService.saveToFiles($0) },
                onShare:       { viewModel.fileSaveService.share($0) }
            ),
            isVisible: viewModel.receivedFiles != nil,
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
                transfer: viewModel.outgoingFileTransfer?.sendingStatus,
                onAbort: { viewModel.abortFileTransfer() }
            ),
            isVisible: viewModel.outgoingFileTransfer != nil,
            isInteractive: viewModel.outgoingFileTransfer != nil,
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
        .fullScreenCover(isPresented: $showFilePicker) {
            FilePickerView(
                onComplete: { urls in
                    showFilePicker = false
                    viewModel.sendFiles(urls)
                },
                onCancel: { showFilePicker = false }
            )
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

    // MARK: - Menu

    private var menuButton: some View {
        Menu {
            Button("Update Profile") { viewModel.goBack() }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 30, height: 30)
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .padding(.top, 8)
        .padding(.trailing, 20)
    }

    // MARK: - Layouts

    private func portraitLayout(maxSheetWidth: CGFloat?) -> some View {
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
        .overlay(alignment: .topTrailing) { menuButton }
        .overlay {
            portraitCurtainView(maxSheetWidth: maxSheetWidth).ignoresSafeArea()
        }
    }

    private func landscapeLayout(leftWidth: CGFloat,
                                 curtainPanelWidth: CGFloat,
                                 curtainRightMargin: CGFloat) -> some View {
        // Left: portrait-equivalent peer area bounded to leftWidth.
        // Right: hero centred in the clear space above the curtain peek, curtain behind it.
        ZStack(alignment: .leading) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            // Left column — same layout as portrait, no curtain-clearance bottom inset.
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
                    SearchPeerGrid(viewModel: viewModel, bottomInset: 40)
                        .transition(.opacity)
                }
            }
            .frame(width: leftWidth)
            .animation(.easeInOut(duration: 0.35), value: viewModel.discoveredPeers.isEmpty)
        }
        .overlay(alignment: .trailing) {
            ZStack {
                // Hero centred vertically between the top edge and the curtain peek.
                // VStack distributes space: Spacer / hero / Spacer / 208pt peek reserve.
                // Result: hero sits at the midpoint of (columnHeight - 208).
                VStack(spacing: 0) {
                    Spacer()
                    SearchHeroSection(viewModel: viewModel, namespace: namespace, showRings: showRings)
                    Spacer()
                    Color.clear.frame(height: 208)
                }
                .overlay(alignment: .topTrailing) { menuButton }

                // Curtain fills the panel. PassthroughView passes touches
                // through the transparent area so the hero above remains tappable.
                landscapeCurtainView
                    .ignoresSafeArea()
            }
            .frame(width: curtainPanelWidth)
            .padding(.trailing, curtainRightMargin)
        }
    }

    private func portraitCurtainView(maxSheetWidth: CGFloat?) -> some View {
        TransferCurtainView(
            viewModel: viewModel,
            maxSheetWidth: maxSheetWidth,
            onShareText:    { showTextShare = true },
            onSharePhoto:   { showMediaPicker = true },
            onShareFile:    { showFilePicker = true },
            onShareContact: { showContactPicker = true }
        )
    }

    /// Landscape variant: scrim suppressed so the dark backdrop doesn't appear
    /// over the hero when the curtain expands. Shadow is unchanged from portrait.
    private var landscapeCurtainView: some View {
        TransferCurtainView(
            viewModel: viewModel,
            disableScrim: true,
            onShareText:    { showTextShare = true },
            onSharePhoto:   { showMediaPicker = true },
            onShareFile:    { showFilePicker = true },
            onShareContact: { showContactPicker = true }
        )
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
