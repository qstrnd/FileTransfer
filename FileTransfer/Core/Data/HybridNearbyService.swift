import Foundation
import OSLog

/// Facade over the app's two nearby transports.
///
/// MultipeerConnectivity remains the control plane — discovery, invitations,
/// text/contact/ping payloads — and the fallback data plane. Bulk payloads
/// (media, files) are routed over a direct local-network HTTP connection to
/// the peer's `HTTPFileTransferServer` when one is reachable, falling back to
/// MPC otherwise (see `TransportPolicy`).
///
/// Externally this class is just a `NearbySessionService`: `AppCoordinator`
/// swaps it in for `MultipeerNearbyService` and nothing else in the app can
/// tell which transport carried a given item — received items surface through
/// the same delegate callbacks, and sends return the same `[Progress]`.
@MainActor
final class HybridNearbyService: NearbySessionService {
    nonisolated private static let log = Logger(subsystem: "com.qstrnd.FileTransfer", category: "HybridTransfer")

    weak var delegate: (any NearbySessionServiceDelegate)?

    private let mpc: MultipeerNearbyService
    private let server: any FileTransferServerGate

    init(
        mpc: MultipeerNearbyService = MultipeerNearbyService(),
        server: any FileTransferServerGate = HTTPFileTransferServer()
    ) {
        self.mpc = mpc
        self.server = server
        mpc.delegate = self
        server.delegate = self
    }

    // MARK: - NearbySessionService (control plane — always MPC)

    func start(displayName: String, deviceID: UUID) {
        mpc.start(displayName: displayName, deviceID: deviceID)
        server.start(deviceID: deviceID, displayName: displayName)
    }

    func stop() {
        mpc.stop()
        server.stop()
    }

    func connect(to peer: Peer, isReconnect: Bool) { mpc.connect(to: peer, isReconnect: isReconnect) }
    func disconnect(from peer: Peer)               { mpc.disconnect(from: peer) }
    func send(text: String, to peer: Peer)         { mpc.send(text: text, to: peer) }
    func sendContact(data: Data, to peer: Peer)    { mpc.sendContact(data: data, to: peer) }
    func sendPing(to peer: Peer)                   { mpc.sendPing(to: peer) }
    func sendPong(to peer: Peer)                   { mpc.sendPong(to: peer) }
    func acceptInvitation()                        { mpc.acceptInvitation() }
    func declineInvitation()                       { mpc.declineInvitation() }

    // MARK: - Data plane (media/files — HTTP with MPC fallback)

    @discardableResult
    func sendMedia(_ files: [MediaFileToSend], to peer: Peer, onItemCompleted: @escaping @MainActor (Result<Void, TransferSendError>) -> Void) -> [Progress] {
        mpc.sendMedia(files, to: peer, onItemCompleted: onItemCompleted)
    }

    @discardableResult
    func sendFiles(_ files: [FileToSend], to peer: Peer, onItemCompleted: @escaping @MainActor (Result<Void, TransferSendError>) -> Void) -> [Progress] {
        mpc.sendFiles(files, to: peer, onItemCompleted: onItemCompleted)
    }
}

// MARK: - NearbySessionServiceDelegate (verbatim forwarding from MPC)

extension HybridNearbyService: NearbySessionServiceDelegate {
    func didDiscover(peer: Peer)                  { delegate?.didDiscover(peer: peer) }
    func didLose(peer: Peer)                      { delegate?.didLose(peer: peer) }
    func didConnect(peer: Peer)                   { delegate?.didConnect(peer: peer) }
    func didDisconnect(peer: Peer)                { delegate?.didDisconnect(peer: peer) }
    func didReceiveInvitation(from peer: Peer)    { delegate?.didReceiveInvitation(from: peer) }
    func didReceiveReconnectInvitation(from peer: Peer) { delegate?.didReceiveReconnectInvitation(from: peer) }
    func didReceive(message: TransferMessage)     { delegate?.didReceive(message: message) }
    func didReceiveContact(data: Data, from peer: Peer) { delegate?.didReceiveContact(data: data, from: peer) }
    func didReceivePing(from peer: Peer)          { delegate?.didReceivePing(from: peer) }
    func didReceivePong(from peer: Peer)          { delegate?.didReceivePong(from: peer) }

    func didStartReceivingMedia(transferID: String, totalCount: Int, from peer: Peer) {
        delegate?.didStartReceivingMedia(transferID: transferID, totalCount: totalCount, from: peer)
    }

    func didReceiveMediaItem(
        transferID: String, index: Int, totalCount: Int,
        at url: URL, kind: MediaFileKind, fileName: String?,
        from peer: Peer
    ) {
        delegate?.didReceiveMediaItem(
            transferID: transferID, index: index, totalCount: totalCount,
            at: url, kind: kind, fileName: fileName, from: peer
        )
    }

    func didStartReceivingFile(transferID: String, totalCount: Int, from peer: Peer) {
        delegate?.didStartReceivingFile(transferID: transferID, totalCount: totalCount, from: peer)
    }

    func didReceiveFile(
        transferID: String, index: Int, totalCount: Int,
        at url: URL, name: String,
        from peer: Peer
    ) {
        delegate?.didReceiveFile(
            transferID: transferID, index: index, totalCount: totalCount,
            at: url, name: name, from: peer
        )
    }
}

// MARK: - FileTransferServerDelegate (HTTP receptions → same delegate callbacks)

extension HybridNearbyService: FileTransferServerDelegate {
    func serverDidStartReceiving(item: IncomingTransferItemInfo, from peer: Peer) {
        switch item.payload {
        case .media:
            // Match the MPC path's behavior: LP companion videos never announce
            // a transfer start (MultipeerNearbyService skips .livePhotoVideo).
            guard item.kind != .livePhotoVideo else { return }
            delegate?.didStartReceivingMedia(transferID: item.transferID, totalCount: item.total, from: peer)
        case .file:
            delegate?.didStartReceivingFile(transferID: item.transferID, totalCount: item.total, from: peer)
        }
    }

    func serverDidReceive(item: IncomingTransferItemInfo, at url: URL, from peer: Peer) {
        switch item.payload {
        case .media:
            delegate?.didReceiveMediaItem(
                transferID: item.transferID, index: item.index, totalCount: item.total,
                at: url, kind: item.kind, fileName: item.fileName, from: peer
            )
        case .file:
            delegate?.didReceiveFile(
                transferID: item.transferID, index: item.index, totalCount: item.total,
                at: url, name: item.fileName ?? "file", from: peer
            )
        }
    }

    func serverReceptionActivityChanged(activeCount: Int) {
        // Phase 2: drives the background-task keeper while receptions are in flight.
    }
}
