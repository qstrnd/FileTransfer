import Foundation

@MainActor
protocol NearbySessionServiceDelegate: AnyObject {
    func didDiscover(peer: Peer)
    func didLose(peer: Peer)
    func didConnect(peer: Peer)
    func didDisconnect(peer: Peer)
    func didReceiveInvitation(from peer: Peer)
    func didReceive(message: TransferMessage)
    func didStartReceivingMedia(transferID: String, totalCount: Int, from peer: Peer)
    func didReceiveMediaItem(
        transferID: String, index: Int, totalCount: Int,
        at url: URL, kind: MediaFileKind, fileName: String?,
        from peer: Peer
    )
    func didReceiveContact(data: Data, from peer: Peer)
}

extension NearbySessionServiceDelegate {
    func didStartReceivingMedia(transferID: String, totalCount: Int, from peer: Peer) {}
    func didReceiveMediaItem(
        transferID: String, index: Int, totalCount: Int,
        at url: URL, kind: MediaFileKind, fileName: String?,
        from peer: Peer
    ) {}
    func didReceiveContact(data: Data, from peer: Peer) {}
}

@MainActor
protocol NearbySessionService: AnyObject {
    var delegate: (any NearbySessionServiceDelegate)? { get set }
    func start(displayName: String, deviceID: UUID)
    func stop()
    func connect(to peer: Peer)
    func disconnect(from peer: Peer)
    func send(text: String, to peer: Peer)
    func sendMedia(_ files: [MediaFileToSend], to peer: Peer, onItemSent: @escaping @MainActor () -> Void)
    func sendContact(data: Data, to peer: Peer)
    func acceptInvitation()
    func declineInvitation()
}

extension NearbySessionService {
    func disconnect(from peer: Peer) {}
    func sendMedia(_ files: [MediaFileToSend], to peer: Peer, onItemSent: @escaping @MainActor () -> Void) {}
    func sendContact(data: Data, to peer: Peer) {}
}
