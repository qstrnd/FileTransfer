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
    func start(displayName: String)
    func stop()
    func connect(to peer: Peer)
    func send(text: String, to peer: Peer)
    func acceptInvitation()
    func declineInvitation()
}
