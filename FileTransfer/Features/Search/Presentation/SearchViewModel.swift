import Contacts
import Foundation
import Observation
import OSLog
import SwiftUI

private let log = Logger(subsystem: "com.qstrnd.FileTransfer", category: "Search")

@Observable
final class SearchViewModel {
    let emoji: String
    let name: String

    var discoveredPeers: [Peer] = []
    var peerStates: [Peer: PeerConnectionState] = [:]
    var pendingInvitationFrom: Peer? = nil
    /// Set briefly when an incoming invitation expires before the user responds.
    var expiredInvitationFrom: Peer? = nil
    /// Set when a text message arrives; cleared when the user dismisses the alert.
    var receivedMessage: TransferMessage? = nil
    /// Set briefly when a previously-connected peer drops without us initiating.
    var disconnectedPeer: Peer? = nil
    /// Tracks an in-progress incoming media transfer; updated as items arrive.
    var receivingMediaTransfer: IncomingMediaTransfer? = nil
    /// Set when all items of a media transfer arrive; cleared when user dismisses.
    var receivedMedia: ReceivedMediaTransfer? = nil
    /// Forwarded from SendMediaUseCase — observed transitively through @Observable.
    var outgoingMediaTransfer: OutgoingMediaTransfer? { sendMediaUseCase.outgoingTransfer }
    /// Forwarded from SendContactUseCase — observed transitively through @Observable.
    var outgoingContactTransfer: OutgoingContactTransfer? { sendContactUseCase.outgoingTransfer }
    /// Set when a contact payload arrives; cleared when the user dismisses the alert.
    var receivedContact: ReceivedContactTransfer?
    /// Live transfer history — reads directly from the @Observable store.
    var transferHistory: [TransferRecord] { historyStore.records }

    /// Set briefly when a peer auto-reconnects; the receiving side sees their name.
    var reconnectedPeer: Peer? = nil
    /// Set briefly when our own connections are restored after going to the foreground.
    var connectionsRestored: Bool = false

    var connectedPeers: [Peer] { peerStates.filter { $0.value == .connected }.map(\.key) }
    var hasConnectedPeers: Bool { !connectedPeers.isEmpty }

    private let deviceID: UUID
    private let service: any NearbySessionService
    private let connectionHistory: any ConnectionHistoryStore
    private let historyStore: TransferHistoryStore
    private let onBack: () -> Void
    let mediaSavingGate: any MediaSavingGate
    let thumbnailGate: any ThumbnailGate
    private let contactShareService = ContactShareService()
    private let sessionAdapter = PeerSessionAdapter()
    private let sendMediaUseCase: SendMediaUseCase
    private let sendContactUseCase: SendContactUseCase

    /// Tracks peers we invited with isReconnect=true so peerConnected can show the toast.
    private var reconnectingPeers: Set<Peer.ID> = []

    init(
        emoji: String,
        name: String,
        deviceID: UUID,
        service: any NearbySessionService,
        connectionHistory: any ConnectionHistoryStore,
        historyStore: TransferHistoryStore,
        mediaSavingGate: any MediaSavingGate = MediaSaveService(),
        thumbnailGate: any ThumbnailGate = MediaThumbnailService(),
        onBack: @escaping () -> Void
    ) {
        self.emoji = emoji
        self.name = name
        self.deviceID = deviceID
        self.service = service
        self.connectionHistory = connectionHistory
        self.historyStore = historyStore
        self.mediaSavingGate = mediaSavingGate
        self.thumbnailGate = thumbnailGate
        self.onBack = onBack
        self.sendMediaUseCase = SendMediaUseCase(session: service, history: historyStore)
        self.sendContactUseCase = SendContactUseCase(session: service, history: historyStore)
        sessionAdapter.events = self
    }

    // MARK: - Lifecycle

    func start() {
        log.info("start — emoji=\(self.emoji, privacy: .public) deviceID=\(self.deviceID, privacy: .public)")
        service.delegate = sessionAdapter
        service.start(displayName: "\(emoji) \(name)", deviceID: deviceID)
    }

    func stop() {
        log.info("stop")
        service.delegate = nil
        service.stop()
    }

    /// Called when the app returns to the foreground. Tears down the current
    /// MPC session (disconnecting all peers) and restarts advertising/browsing
    /// so discovery begins fresh without stale peer state.
    func handleForeground() {
        log.info("handleForeground — resetting session")
        reconnectingPeers = []
        // Clear state BEFORE stopping so that any async delegate callbacks
        // triggered by session.disconnect() land on an already-clean map
        // and cannot re-set peers to .connected.
        withAnimation {
            peerStates = [:]
            discoveredPeers = []
            pendingInvitationFrom = nil
            expiredInvitationFrom = nil
        }
        service.stop()
        service.start(displayName: "\(emoji) \(name)", deviceID: deviceID)
    }

    func goBack() {
        log.info("goBack")
        stop()
        onBack()
    }

    // MARK: - Actions

    func connect(to peer: Peer) {
        initiateConnect(to: peer, isReconnect: false)
    }

    private func initiateConnect(to peer: Peer, isReconnect: Bool) {
        let current = peerStates[peer] ?? .idle
        log.info("connect — peer=\(peer.displayName, privacy: .public) isReconnect=\(isReconnect) currentState=\(String(describing: current), privacy: .public)")
        guard ConnectionPolicy.canInitiate(from: current),
              let next = current.applying(.initiateConnection) else {
            log.warning("connect — blocked by policy from state \(String(describing: current), privacy: .public)")
            return
        }
        peerStates[peer] = next
        if isReconnect { reconnectingPeers.insert(peer.id) }
        service.connect(to: peer, isReconnect: isReconnect)

        // Failsafe: fires 3 s after the MPC invitation timeout so MPC's own
        // didDisconnect has a chance to set the proper .rejected state first.
        Task {
            try? await Task.sleep(for: .seconds(mcInvitationTimeout + 3))
            if peerStates[peer] == .connecting {
                log.warning("connect — failsafe fired for \(peer.displayName, privacy: .public); resetting to idle")
                withAnimation(.spring(duration: 0.4)) { peerStates[peer] = .idle }
                reconnectingPeers.remove(peer.id)
            }
        }
    }

    func disconnectAll() {
        connectedPeers.forEach { disconnect(from: $0) }
    }

    func sendText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        for peer in connectedPeers {
            service.send(text: trimmed, to: peer)
            addRecord(TransferRecord(
                peerEmoji: peer.emojiComponent,
                peerName: peer.nameComponent,
                direction: .sent,
                type: .text,
                detail: trimmed
            ))
        }
    }

    func sendMedia(_ items: [MediaItem]) {
        sendMediaUseCase.send(items, to: connectedPeers)
    }

    func abortMediaTransfer() {
        sendMediaUseCase.abort()
        disconnectAll()
    }

    func sendContacts(_ contacts: [CNContact]) {
        sendContactUseCase.send(contacts, to: connectedPeers)
    }

    func abortContactTransfer() {
        sendContactUseCase.abort()
    }

    func shareReceivedContact(vCardData: Data) {
        let name = receivedContact.map { Peer.parseDisplayName($0.senderName).name } ?? ""
        contactShareService.share(vCardData: vCardData, senderName: name)
    }

    private func addRecord(_ record: TransferRecord) {
        historyStore.add(record)
    }

    // MARK: - Reconnect toasts

    /// Shows the per-peer "NAME is connected" toast — for the receiving side of a reconnect.
    private func showReconnectedPeerToast(for peer: Peer) {
        withAnimation { reconnectedPeer = peer }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { if reconnectedPeer == peer { reconnectedPeer = nil } }
        }
    }

    /// Shows the generic "Connections are restored" toast — for the initiating side.
    private func showConnectionsRestoredToast() {
        withAnimation { connectionsRestored = true }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { connectionsRestored = false }
        }
    }

    func disconnect(from peer: Peer) {
        let current = peerStates[peer] ?? .idle
        log.info("disconnect — peer=\(peer.displayName, privacy: .public) currentState=\(String(describing: current), privacy: .public)")
        guard let next = current.applying(.initiateDisconnection) else {
            log.warning("disconnect — invalid from state \(String(describing: current), privacy: .public)")
            return
        }
        withAnimation(.spring(duration: 0.4)) { peerStates[peer] = next }
        log.debug("disconnect — state \(String(describing: current), privacy: .public) → \(String(describing: next), privacy: .public)")
        service.disconnect(from: peer)
    }

    func acceptInvitation() {
        log.info("acceptInvitation — from=\(self.pendingInvitationFrom?.displayName ?? "nil", privacy: .public)")
        guard let peer = pendingInvitationFrom else { return }
        // The receiving side never went through .connecting (they didn't initiate),
        // so the state machine doesn't apply here — set .connected directly.
        withAnimation { peerStates[peer] = .connected }
        service.acceptInvitation()
        pendingInvitationFrom = nil
    }

    func declineInvitation() {
        log.info("declineInvitation — from=\(self.pendingInvitationFrom?.displayName ?? "nil", privacy: .public)")
        service.declineInvitation()
        pendingInvitationFrom = nil
    }
}

// MARK: - PeerSessionEvents

extension SearchViewModel: PeerSessionEvents {
    func peerDiscovered(_ peer: Peer) {
        log.info("didDiscover — \(peer.displayName, privacy: .public) deviceID=\(peer.deviceID?.uuidString ?? "nil", privacy: .public)")
        guard !discoveredPeers.contains(peer) else { return }
        withAnimation(.spring(duration: 0.35)) { discoveredPeers.append(peer) }
        maybeAutoReconnect(to: peer)
    }

    private func maybeAutoReconnect(to peer: Peer) {
        guard let peerDeviceID = peer.deviceID,
              connectionHistory.hasConnected(to: peerDeviceID),
              (peerStates[peer] ?? .idle) == .idle,
              // Tiebreaker: the device with the higher UUID string initiates to
              // prevent both sides from sending crossing invitations simultaneously.
              deviceID.uuidString > peerDeviceID.uuidString else { return }

        log.info("peerDiscovered — scheduling auto-reconnect to \(peer.displayName, privacy: .public)")
        Task {
            // Brief settle delay before inviting.
            try? await Task.sleep(for: .milliseconds(500))
            guard discoveredPeers.contains(peer), (peerStates[peer] ?? .idle) == .idle else { return }
            log.info("peerDiscovered — auto-reconnecting to \(peer.displayName, privacy: .public)")
            initiateConnect(to: peer, isReconnect: true)
        }
    }

    func peerLost(_ peer: Peer) {
        log.info("didLose — \(peer.displayName, privacy: .public)")
        withAnimation(.spring(duration: 0.35)) {
            discoveredPeers.removeAll { $0 == peer }
            peerStates.removeValue(forKey: peer)
        }
    }

    func peerConnected(_ peer: Peer) {
        let preState = peerStates[peer]
        log.info("didConnect — \(peer.displayName, privacy: .public) currentState=\(String(describing: preState), privacy: .public)")

        // Only honour connection events for peers we explicitly interacted with.
        // If preState is nil or .idle the connection is unsolicited (e.g. MPC
        // auto-reconnect after returning from background). Accepting it would
        // silently restore the connected UI even though we reset on foreground.
        guard preState == .connecting || preState == .connected else {
            log.warning("didConnect — ignoring unsolicited connection from \(peer.displayName, privacy: .public) (state=\(String(describing: preState), privacy: .public))")
            return
        }

        if preState == .connected {
            // Receiving side already set .connected in acceptInvitation.
            connectionHistory.record(peer: peer)
            log.debug("didConnect — already connected (receiving side), history updated")
            return
        }
        guard let next = preState!.applying(.connectionAccepted) else { return }
        withAnimation { peerStates[peer] = next }
        connectionHistory.record(peer: peer)
        log.debug("didConnect — state → \(String(describing: next), privacy: .public); history updated")

        if reconnectingPeers.remove(peer.id) != nil {
            showConnectionsRestoredToast()
        }
    }

    func peerDisconnected(_ peer: Peer) {
        reconnectingPeers.remove(peer.id)
        let current = peerStates[peer] ?? .idle
        let event: ConnectionEvent = (current == .connecting) ? .connectionDeclined : .peerDisconnected
        log.info("didDisconnect — \(peer.displayName, privacy: .public) currentState=\(String(describing: current), privacy: .public) event=\(String(describing: event), privacy: .public)")
        guard let next = current.applying(event) else {
            log.warning("didDisconnect — invalid transition from \(String(describing: current), privacy: .public)")
            return
        }
        withAnimation { peerStates[peer] = next }
        log.debug("didDisconnect — state → \(String(describing: next), privacy: .public)")

        // Remote-initiated disconnect from an established connection.
        // When WE initiate, disconnect(from:) updates peerStates[peer] to a
        // non-.connected state before service.disconnect() is called, so by the
        // time this delegate fires current is already the post-transition value.
        if current == .connected {
            withAnimation { disconnectedPeer = peer }
            Task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation { if disconnectedPeer == peer { disconnectedPeer = nil } }
            }
        }

        if next == .rejected {
            Task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation(.spring(duration: 0.4)) {
                    if peerStates[peer] == .rejected { peerStates[peer] = .idle }
                }
                log.debug("didDisconnect — rejected state cleared for \(peer.displayName, privacy: .public)")
            }
        }
    }

    func invitationReceived(from peer: Peer) {
        log.info("didReceiveInvitation — from \(peer.displayName, privacy: .public)")
        pendingInvitationFrom = peer

        // Auto-dismiss the alert after the MPC invitation timeout so the alert
        // does not linger forever. Show a brief banner so the user knows why it disappeared.
        Task {
            try? await Task.sleep(for: .seconds(mcInvitationTimeout))
            guard pendingInvitationFrom == peer else { return }
            log.info("didReceiveInvitation — timeout; auto-dismissing alert for \(peer.displayName, privacy: .public)")
            withAnimation {
                pendingInvitationFrom = nil
                expiredInvitationFrom = peer
            }
            try? await Task.sleep(for: .seconds(4))
            withAnimation { expiredInvitationFrom = nil }
        }
    }

    func reconnectInvitationReceived(from peer: Peer) {
        log.info("reconnectInvitationReceived — from \(peer.displayName, privacy: .public)")
        guard let peerDeviceID = peer.deviceID,
              connectionHistory.hasConnected(to: peerDeviceID) else {
            log.info("reconnectInvitationReceived — peer not in history, falling back to manual invite for \(peer.displayName, privacy: .public)")
            invitationReceived(from: peer)
            return
        }
        log.info("reconnectInvitationReceived — auto-accepting for \(peer.displayName, privacy: .public)")
        withAnimation { peerStates[peer] = .connected }
        service.acceptInvitation()
        showReconnectedPeerToast(for: peer)
    }

    func messageReceived(_ message: TransferMessage) {
        log.debug("didReceive — from \(message.senderName, privacy: .public): \(message.text, privacy: .private)")
        receivedMessage = message
        let (emoji, name) = Peer.parseDisplayName(message.senderName)
        addRecord(TransferRecord(
            peerEmoji: emoji,
            peerName: name,
            direction: .received,
            type: .text,
            detail: message.text
        ))
    }

    func mediaTransferStarted(transferID: String, totalCount: Int, from peer: Peer) {
        guard receivingMediaTransfer?.id != transferID else { return }
        receivingMediaTransfer = IncomingMediaTransfer(
            id: transferID, senderName: peer.displayName, totalCount: totalCount
        )
    }

    func contactReceived(data: Data, from peer: Peer) {
        guard let rawContacts = try? CNContactVCardSerialization.contacts(with: data) else { return }

        let contactItems = rawContacts.map { contact in
            let displayName = CNContactFormatter.string(from: contact, style: .fullName) ?? "Unknown"
            let phones = contact.phoneNumbers.map { $0.value.stringValue }
            let emails = contact.emailAddresses.map { $0.value as String }
            return ContactItem(displayName: displayName, phoneNumbers: phones, emailAddresses: emails)
        }

        let (emoji, name) = Peer.parseDisplayName(peer.displayName)
        let detail = contactItems.count == 1 ? contactItems[0].displayName : "\(contactItems.count) contacts"
        addRecord(TransferRecord(
            peerEmoji: emoji, peerName: name,
            direction: .received, type: .contact, detail: detail
        ))

        receivedContact = ReceivedContactTransfer(
            senderName: peer.displayName,
            contacts: contactItems,
            vCardData: data
        )
    }

    func mediaItemReceived(
        transferID: String, index: Int, totalCount: Int,
        at url: URL, kind: MediaFileKind, fileName: String?,
        from peer: Peer
    ) {
        if receivingMediaTransfer == nil || receivingMediaTransfer?.id != transferID {
            receivingMediaTransfer = IncomingMediaTransfer(
                id: transferID, senderName: peer.displayName, totalCount: totalCount
            )
        }
        receivingMediaTransfer?.add(url: url, at: index, kind: kind, fileName: fileName)

        guard receivingMediaTransfer?.isComplete == true,
              let transfer = receivingMediaTransfer else { return }

        let senderName = transfer.senderName
        let items = transfer.buildItems(transferID: transferID)
        let (emoji, name) = Peer.parseDisplayName(peer.displayName)
        addRecord(TransferRecord(
            peerEmoji: emoji,
            peerName: name,
            direction: .received,
            type: .photo,
            detail: "\(transfer.totalCount) item\(transfer.totalCount == 1 ? "" : "s")"
        ))
        Task {
            // Keep the receiving toast visible for a moment so the user sees
            // the transfer complete before the received-media alert appears.
            try? await Task.sleep(for: .seconds(1.2))
            receivingMediaTransfer = nil
            receivedMedia = ReceivedMediaTransfer(senderName: senderName, items: items)
        }
    }
}

// MARK: - View helpers

extension SearchViewModel {
    var peerRows: [[Peer]] {
        stride(from: 0, to: discoveredPeers.count, by: 2).map { i in
            Array(discoveredPeers[i..<min(i + 2, discoveredPeers.count)])
        }
    }
}
