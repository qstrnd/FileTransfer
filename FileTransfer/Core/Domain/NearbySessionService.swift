import Foundation

@MainActor
protocol NearbySessionServiceDelegate: AnyObject {
    func didDiscover(peer: Peer)
    func didLose(peer: Peer)
    func didConnect(peer: Peer)
    func didDisconnect(peer: Peer)
    func didReceiveInvitation(from peer: Peer)
    /// Called instead of `didReceiveInvitation` when the sender flagged the invite as a reconnect.
    /// Implementations should auto-accept if the peer is in connection history.
    func didReceiveReconnectInvitation(from peer: Peer)
    func didReceive(message: TransferMessage)
    func didStartReceivingMedia(transferID: String, totalCount: Int, from peer: Peer)
    func didReceiveMediaItem(
        transferID: String, index: Int, totalCount: Int,
        at url: URL, kind: MediaFileKind, fileName: String?,
        from peer: Peer
    )
    func didReceiveContact(data: Data, from peer: Peer)
    func didReceivePing(from peer: Peer)
    func didReceivePong(from peer: Peer)
}

extension NearbySessionServiceDelegate {
    func didReceiveReconnectInvitation(from peer: Peer) {}
    func didStartReceivingMedia(transferID: String, totalCount: Int, from peer: Peer) {}
    func didReceiveMediaItem(
        transferID: String, index: Int, totalCount: Int,
        at url: URL, kind: MediaFileKind, fileName: String?,
        from peer: Peer
    ) {}
    func didReceiveContact(data: Data, from peer: Peer) {}
    func didReceivePing(from peer: Peer) {}
    func didReceivePong(from peer: Peer) {}
}

@MainActor
protocol NearbySessionService: AnyObject {
    var delegate: (any NearbySessionServiceDelegate)? { get set }
    func start(displayName: String, deviceID: UUID)
    func stop()
    func connect(to peer: Peer, isReconnect: Bool)
    func disconnect(from peer: Peer)
    func send(text: String, to peer: Peer)
    func sendMedia(_ files: [MediaFileToSend], to peer: Peer, onItemSent: @escaping @MainActor () -> Void)
    func sendContact(data: Data, to peer: Peer)
    func sendPing(to peer: Peer)
    func sendPong(to peer: Peer)
    func acceptInvitation()
    func declineInvitation()
}

extension NearbySessionService {
    func connect(to peer: Peer) { connect(to: peer, isReconnect: false) }
    func disconnect(from peer: Peer) {}
    func sendMedia(_ files: [MediaFileToSend], to peer: Peer, onItemSent: @escaping @MainActor () -> Void) {}
    func sendContact(data: Data, to peer: Peer) {}
    func sendPing(to peer: Peer) {}
    func sendPong(to peer: Peer) {}
}
