import Foundation
import Observation
import SwiftUI

@Observable
final class SearchViewModel {
    let emoji: String
    let name: String

    var discoveredPeers: [Peer] = []
    var peerStates: [Peer: PeerConnectionState] = [:]
    var pendingInvitationFrom: Peer? = nil

    var connectedPeers: [Peer] { peerStates.filter { $0.value == .connected }.map(\.key) }
    var hasConnectedPeers: Bool { !connectedPeers.isEmpty }

    private let deviceID: UUID
    private let service: any NearbySessionService
    private let connectionHistory: any ConnectionHistoryStore
    private let onBack: () -> Void

    init(
        emoji: String,
        name: String,
        deviceID: UUID,
        service: any NearbySessionService,
        connectionHistory: any ConnectionHistoryStore,
        onBack: @escaping () -> Void
    ) {
        self.emoji = emoji
        self.name = name
        self.deviceID = deviceID
        self.service = service
        self.connectionHistory = connectionHistory
        self.onBack = onBack
    }

    // MARK: - Lifecycle

    func start() {
        service.delegate = self
        service.start(displayName: "\(emoji) \(name)", deviceID: deviceID)
    }

    func stop() {
        service.delegate = nil
        service.stop()
    }

    func goBack() {
        stop()
        onBack()
    }

    // MARK: - Actions

    /// Route `initiateConnection` through `ConnectionPolicy` so business rules
    /// are the single source of truth for which states allow (re-)connecting.
    func connect(to peer: Peer) {
        let current = peerStates[peer] ?? .idle
        guard ConnectionPolicy.canInitiate(from: current),
              let next = current.applying(.initiateConnection) else { return }

        peerStates[peer] = next
        service.connect(to: peer)

        // Failsafe: MPC does not always fire didDisconnect for silent rejections.
        Task {
            try? await Task.sleep(for: .seconds(10))
            if peerStates[peer] == .connecting {
                withAnimation(.spring(duration: 0.4)) { peerStates[peer] = .idle }
            }
        }
    }

    func disconnect(from peer: Peer) {
        guard let next = (peerStates[peer] ?? .idle).applying(.initiateDisconnection) else { return }
        withAnimation(.spring(duration: 0.4)) { peerStates[peer] = next }
        // Note: MCSession has no per-peer disconnect API. Calling session.disconnect()
        // disconnects all peers; instead we rely on the state update here and let
        // MPC fire didDisconnect on the remote side when the session is eventually torn down.
    }

    func acceptInvitation() {
        if let peer = pendingInvitationFrom {
            guard let next = (peerStates[peer] ?? .idle).applying(.connectionAccepted) else { return }
            peerStates[peer] = next
        }
        service.acceptInvitation()
        pendingInvitationFrom = nil
    }

    func declineInvitation() {
        service.declineInvitation()
        pendingInvitationFrom = nil
    }
}

// MARK: - NearbySessionServiceDelegate

extension SearchViewModel: NearbySessionServiceDelegate {
    func didDiscover(peer: Peer) {
        guard !discoveredPeers.contains(peer) else { return }
        withAnimation(.spring(duration: 0.35)) { discoveredPeers.append(peer) }
    }

    func didLose(peer: Peer) {
        withAnimation(.spring(duration: 0.35)) {
            discoveredPeers.removeAll { $0 == peer }
            peerStates.removeValue(forKey: peer)
        }
    }

    func didConnect(peer: Peer) {
        guard let next = (peerStates[peer] ?? .connecting).applying(.connectionAccepted) else { return }
        withAnimation { peerStates[peer] = next }
        // Rule 5: persist the connection so the two devices qualify for future auto-reconnect.
        connectionHistory.record(peer: peer)
    }

    func didDisconnect(peer: Peer) {
        let current = peerStates[peer] ?? .idle
        // If we were connecting and the peer disconnected, they declined our invitation.
        let event: ConnectionEvent = (current == .connecting) ? .connectionDeclined : .peerDisconnected
        guard let next = current.applying(event) else { return }
        withAnimation { peerStates[peer] = next }

        if next == .rejected {
            Task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation(.spring(duration: 0.4)) {
                    if peerStates[peer] == .rejected { peerStates[peer] = .idle }
                }
            }
        }
    }

    func didReceiveInvitation(from peer: Peer) {
        pendingInvitationFrom = peer
    }

    func didReceive(message: TransferMessage) {}
}

// MARK: - View helpers

extension SearchViewModel {
    var peerRows: [[Peer]] {
        stride(from: 0, to: discoveredPeers.count, by: 2).map { i in
            Array(discoveredPeers[i..<min(i + 2, discoveredPeers.count)])
        }
    }
}
