import Foundation
import Observation

@Observable
final class TransferViewModel {
    var discoveredPeers: [Peer] = []
    var connectedPeers: [Peer] = []
    var receivedMessages: [TransferMessage] = []
    var pendingInvitationFrom: Peer?
    var lastReceivedMessage: TransferMessage?

    private let service: any NearbySessionService
    private let onStop: () -> Void

    init(service: any NearbySessionService, onStop: @escaping () -> Void) {
        self.service = service
        self.onStop = onStop
        service.delegate = self
    }

    func stop() {
        service.stop()
        onStop()
    }

    func connect(to peer: Peer) {
        service.connect(to: peer)
    }

    func send(text: String, to peer: Peer) {
        service.send(text: text, to: peer)
    }

    func acceptInvitation() {
        service.acceptInvitation()
        pendingInvitationFrom = nil
    }

    func declineInvitation() {
        service.declineInvitation()
        pendingInvitationFrom = nil
    }
}

extension TransferViewModel: NearbySessionServiceDelegate {
    func didDiscover(peer: Peer) {
        if !discoveredPeers.contains(peer) { discoveredPeers.append(peer) }
    }

    func didLose(peer: Peer) {
        discoveredPeers.removeAll { $0 == peer }
    }

    func didConnect(peer: Peer) {
        connectedPeers.append(peer)
        discoveredPeers.removeAll { $0 == peer }
    }

    func didDisconnect(peer: Peer) {
        connectedPeers.removeAll { $0 == peer }
    }

    func didReceiveInvitation(from peer: Peer) {
        pendingInvitationFrom = peer
    }

    func didReceive(message: TransferMessage) {
        receivedMessages.append(message)
        lastReceivedMessage = message
    }
}
