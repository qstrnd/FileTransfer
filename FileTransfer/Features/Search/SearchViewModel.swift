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
    /// Live transfer history sourced from persistent storage.
    private(set) var transferHistory: [TransferRecord] = []

    var connectedPeers: [Peer] { peerStates.filter { $0.value == .connected }.map(\.key) }
    var hasConnectedPeers: Bool { !connectedPeers.isEmpty }

    private let deviceID: UUID
    private let service: any NearbySessionService
    private let connectionHistory: any ConnectionHistoryStore
    private let historyStore: TransferHistoryStore
    private let onBack: () -> Void

    init(
        emoji: String,
        name: String,
        deviceID: UUID,
        service: any NearbySessionService,
        connectionHistory: any ConnectionHistoryStore,
        historyStore: TransferHistoryStore,
        onBack: @escaping () -> Void
    ) {
        self.emoji = emoji
        self.name = name
        self.deviceID = deviceID
        self.service = service
        self.connectionHistory = connectionHistory
        self.historyStore = historyStore
        self.onBack = onBack
        self.transferHistory = historyStore.records
    }

    // MARK: - Lifecycle

    func start() {
        log.info("start — emoji=\(self.emoji, privacy: .public) deviceID=\(self.deviceID, privacy: .public)")
        service.delegate = self
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
        let current = peerStates[peer] ?? .idle
        log.info("connect — peer=\(peer.displayName, privacy: .public) currentState=\(String(describing: current), privacy: .public)")
        guard ConnectionPolicy.canInitiate(from: current),
              let next = current.applying(.initiateConnection) else {
            log.warning("connect — blocked by policy from state \(String(describing: current), privacy: .public)")
            return
        }
        peerStates[peer] = next
        log.debug("connect — state \(String(describing: current), privacy: .public) → \(String(describing: next), privacy: .public)")
        service.connect(to: peer)

        // Failsafe: fires 3 s after the MPC invitation timeout so MPC's own
        // didDisconnect has a chance to set the proper .rejected state first.
        Task {
            try? await Task.sleep(for: .seconds(mcInvitationTimeout + 3))
            if peerStates[peer] == .connecting {
                log.warning("connect — failsafe fired for \(peer.displayName, privacy: .public); resetting to idle")
                withAnimation(.spring(duration: 0.4)) { peerStates[peer] = .idle }
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

    private func addRecord(_ record: TransferRecord) {
        historyStore.add(record)
        transferHistory = historyStore.records
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

// MARK: - NearbySessionServiceDelegate

extension SearchViewModel: NearbySessionServiceDelegate {
    func didDiscover(peer: Peer) {
        log.info("didDiscover — \(peer.displayName, privacy: .public) deviceID=\(peer.deviceID?.uuidString ?? "nil", privacy: .public)")
        guard !discoveredPeers.contains(peer) else { return }
        withAnimation(.spring(duration: 0.35)) { discoveredPeers.append(peer) }
    }

    func didLose(peer: Peer) {
        log.info("didLose — \(peer.displayName, privacy: .public)")
        withAnimation(.spring(duration: 0.35)) {
            discoveredPeers.removeAll { $0 == peer }
            peerStates.removeValue(forKey: peer)
        }
    }

    func didConnect(peer: Peer) {
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
    }

    func didDisconnect(peer: Peer) {
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

    func didReceiveInvitation(from peer: Peer) {
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

    func didReceive(message: TransferMessage) {
        log.debug("didReceive — from \(message.senderName, privacy: .public): \(message.text, privacy: .private)")
        receivedMessage = message
        // senderName is the peer's full displayName: "🦒 Cunning Giraffe"
        let emoji = String(message.senderName.prefix(1))
        let name: String
        if let spaceIdx = message.senderName.firstIndex(of: " ") {
            name = String(message.senderName[message.senderName.index(after: spaceIdx)...])
        } else {
            name = message.senderName
        }
        addRecord(TransferRecord(
            peerEmoji: emoji,
            peerName: name,
            direction: .received,
            type: .text,
            detail: message.text
        ))
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
