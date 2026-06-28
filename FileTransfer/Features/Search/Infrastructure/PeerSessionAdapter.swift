import Foundation

// MARK: - PeerSessionEvents

/// Events the ViewModel must handle in response to peer activity.
/// Named from the ViewModel's perspective, not the service's.
@MainActor
protocol PeerSessionEvents: AnyObject {
    func peerDiscovered(_ peer: Peer)
    func peerLost(_ peer: Peer)
    func peerConnected(_ peer: Peer)
    func peerDisconnected(_ peer: Peer)
    func invitationReceived(from peer: Peer)
    func messageReceived(_ message: TransferMessage)
    func mediaTransferStarted(transferID: String, totalCount: Int, from peer: Peer)
    func mediaItemReceived(
        transferID: String, index: Int, totalCount: Int,
        at url: URL, kind: MediaFileKind, fileName: String?,
        from peer: Peer
    )
    func contactReceived(data: Data, from peer: Peer)
}

// MARK: - PeerSessionAdapter

/// Translates NearbySessionService delegate callbacks into PeerSessionEvents,
/// decoupling SearchViewModel from the service-layer protocol.
final class PeerSessionAdapter: NearbySessionServiceDelegate {
    weak var events: (any PeerSessionEvents)?

    func didDiscover(peer: Peer)                   { events?.peerDiscovered(peer) }
    func didLose(peer: Peer)                        { events?.peerLost(peer) }
    func didConnect(peer: Peer)                     { events?.peerConnected(peer) }
    func didDisconnect(peer: Peer)                  { events?.peerDisconnected(peer) }
    func didReceiveInvitation(from peer: Peer)      { events?.invitationReceived(from: peer) }
    func didReceive(message: TransferMessage)       { events?.messageReceived(message) }

    func didStartReceivingMedia(transferID: String, totalCount: Int, from peer: Peer) {
        events?.mediaTransferStarted(transferID: transferID, totalCount: totalCount, from: peer)
    }

    func didReceiveMediaItem(
        transferID: String, index: Int, totalCount: Int,
        at url: URL, kind: MediaFileKind, fileName: String?,
        from peer: Peer
    ) {
        events?.mediaItemReceived(
            transferID: transferID, index: index, totalCount: totalCount,
            at: url, kind: kind, fileName: fileName, from: peer
        )
    }

    func didReceiveContact(data: Data, from peer: Peer) {
        events?.contactReceived(data: data, from: peer)
    }
}
