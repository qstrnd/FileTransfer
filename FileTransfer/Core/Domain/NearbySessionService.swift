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
    /// Start advertising and browsing.
    /// `deviceID` is broadcast via MPC discoveryInfo so remote peers can identify
    /// this device for connection-history lookup and future auto-reconnect.
    func start(displayName: String, deviceID: UUID)
    func stop()
    func connect(to peer: Peer)
    func send(text: String, to peer: Peer)
    func acceptInvitation()
    func declineInvitation()
}
