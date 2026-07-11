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
    private let endpointResolver: any PeerEndpointResolving
    private let policy: any TransportPolicy
    private let httpSender: any HTTPTransferSending

    init(
        mpc: MultipeerNearbyService = MultipeerNearbyService(),
        server: any FileTransferServerGate = HTTPFileTransferServer(),
        endpointResolver: any PeerEndpointResolving = BonjourPeerEndpointResolver(),
        policy: any TransportPolicy = DefaultTransportPolicy(),
        httpSender: (any HTTPTransferSending)? = nil
    ) {
        self.mpc = mpc
        self.server = server
        self.endpointResolver = endpointResolver
        self.policy = policy
        // Mini composition root for the transfer stack: the coordinator needs
        // the same MPC instance (for transferID-preserving fallback) and the
        // same resolver (for endpoint refresh between retries). The upload
        // client is the shared background-session instance so cold background
        // launches can reattach it before any facade exists.
        self.httpSender = httpSender ?? HTTPTransferSendCoordinator(
            uploadGate: BackgroundURLSessionUploadClient.shared,
            endpointResolver: endpointResolver,
            mpcFallback: mpc
        )
        mpc.delegate = self
        server.delegate = self
    }

    // MARK: - NearbySessionService (control plane — always MPC)

    func start(displayName: String, deviceID: UUID) {
        mpc.start(displayName: displayName, deviceID: deviceID)
        server.start(deviceID: deviceID, displayName: displayName)
        endpointResolver.start()
        httpSender.setLocalIdentity(deviceID: deviceID, displayName: displayName)
    }

    /// Stops the control plane immediately, but with drain semantics for the
    /// data plane: in-flight HTTP receptions finish under a background task,
    /// and in-flight background uploads are deliberately NOT cancelled — they
    /// continue in nsurlsessiond after the app suspends. (The view model
    /// calls stop() on every backgrounding.) While stopped, MPC fallback is
    /// unavailable, so uploads that fail late report an honest failure.
    func stop() {
        mpc.stop()
        endpointResolver.stop()
        if server.activeReceptionCount > 0 {
            backgroundKeeper.hasActiveWork = true
            server.drain()
        } else {
            server.stop()
        }
    }

    private let backgroundKeeper = BackgroundActivityKeeper()

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
        switch dataTransport(for: .media, to: peer, files: files.map(\.url)) {
        case .http(let endpoint):
            return httpSender.sendMedia(files, to: peer, endpoint: endpoint, onItemCompleted: onItemCompleted)
        case .multipeer:
            return mpc.sendMedia(files, to: peer, onItemCompleted: onItemCompleted)
        }
    }

    @discardableResult
    func sendFiles(_ files: [FileToSend], to peer: Peer, onItemCompleted: @escaping @MainActor (Result<Void, TransferSendError>) -> Void) -> [Progress] {
        switch dataTransport(for: .file, to: peer, files: files.map(\.url)) {
        case .http(let endpoint):
            return httpSender.sendFiles(files, to: peer, endpoint: endpoint, onItemCompleted: onItemCompleted)
        case .multipeer:
            return mpc.sendFiles(files, to: peer, onItemCompleted: onItemCompleted)
        }
    }

    private func dataTransport(for payload: TransferPayloadKind, to peer: Peer, files: [URL]) -> TransferTransport {
        let endpoint = peer.deviceID.flatMap { endpointResolver.cachedEndpoint(for: $0) }
        let totalBytes = files.reduce(Int64(0)) { sum, url in
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int64
            return sum + (size ?? 0)
        }
        let transport = policy.transport(payload: payload, totalBytes: totalBytes, endpoint: endpoint)
        Self.log.info("route \(files.count) file(s), \(totalBytes) bytes → \(String(describing: transport), privacy: .public)")
        return transport
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
        // Keeps the process alive through brief backgrounding while receptions
        // are mid-flight; released (after a grace period) when they drain.
        backgroundKeeper.hasActiveWork = activeCount > 0
    }
}
