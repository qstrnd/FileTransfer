import Foundation
import Observation
import SwiftUI

@Observable
final class SearchViewModel {
    let emoji: String
    let name: String

    // Peers in discovery order; animated when entries are added/removed.
    var discoveredPeers: [Peer] = []
    // Per-peer connection state machine.
    var peerStates: [Peer: PeerConnectionState] = [:]
    // Non-nil while an incoming invitation is waiting for the user's answer.
    var pendingInvitationFrom: Peer? = nil

    var connectedPeers: [Peer] { peerStates.filter { $0.value == .connected }.map(\.key) }
    var hasConnectedPeers: Bool { !connectedPeers.isEmpty }

    private let service: any NearbySessionService
    private let onBack: () -> Void

    init(emoji: String, name: String, service: any NearbySessionService, onBack: @escaping () -> Void) {
        self.emoji = emoji
        self.name = name
        self.service = service
        self.onBack = onBack
    }

    // MARK: - Lifecycle

    func start() {
        service.delegate = self
        service.start(displayName: "\(emoji) \(name)")
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

    func connect(to peer: Peer) {
        switch peerStates[peer] ?? .idle {
        case .connected:
            disconnect(from: peer)
        case .idle, .rejected:
            peerStates[peer] = .connecting
            service.connect(to: peer)
            // Failsafe: MPC doesn't always fire didDisconnect for silent rejections.
            // Reset to idle after the invitation timeout so the user can try again.
            Task {
                try? await Task.sleep(for: .seconds(10))
                if peerStates[peer] == .connecting {
                    withAnimation(.spring(duration: 0.4)) { peerStates[peer] = .idle }
                }
            }
        case .connecting:
            break
        }
    }

    func disconnect(from peer: Peer) {
        withAnimation(.spring(duration: 0.4)) { peerStates[peer] = .idle }
    }

    func acceptInvitation() {
        if let peer = pendingInvitationFrom {
            peerStates[peer] = .connected
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
        withAnimation { peerStates[peer] = .connected }
    }

    func didDisconnect(peer: Peer) {
        let wasConnecting = peerStates[peer] == .connecting
        withAnimation {
            peerStates[peer] = wasConnecting ? .rejected : .idle
        }
        guard wasConnecting else { return }
        // Reset to idle after the rejection animation plays so the user can try again.
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.spring(duration: 0.4)) {
                if peerStates[peer] == .rejected { peerStates[peer] = .idle }
            }
        }
    }

    func didReceiveInvitation(from peer: Peer) {
        pendingInvitationFrom = peer
    }

    func didReceive(message: TransferMessage) {}
}
