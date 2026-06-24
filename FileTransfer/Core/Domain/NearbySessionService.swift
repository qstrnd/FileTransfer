import Foundation

@MainActor
protocol NearbySessionServiceDelegate: AnyObject {
    func didDiscover(peer: Peer)
    func didLose(peer: Peer)
    func didConnect(peer: Peer)
    func didDisconnect(peer: Peer)
    func didReceiveInvitation(from peer: Peer)
    func didReceive(message: TransferMessage)
}

@MainActor
protocol NearbySessionService: AnyObject {
    var delegate: (any NearbySessionServiceDelegate)? { get set }
    func start(displayName: String, deviceID: UUID)
    func stop()
    func connect(to peer: Peer)
    /// Disconnect from `peer`. Concrete implementations should sever the MPC
    /// session so the remote side also receives a disconnect callback.
    func disconnect(from peer: Peer)
    func send(text: String, to peer: Peer)
    func acceptInvitation()
    func declineInvitation()
}

// Default no-op so legacy/preview conformers don't need to change.
extension NearbySessionService {
    func disconnect(from peer: Peer) {}
}
