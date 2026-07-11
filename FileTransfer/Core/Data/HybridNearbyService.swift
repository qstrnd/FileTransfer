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
    private let activityGate: any TransferActivityGate

    init(
        mpc: MultipeerNearbyService = MultipeerNearbyService(),
        server: any FileTransferServerGate = HTTPFileTransferServer(),
        endpointResolver: any PeerEndpointResolving = BonjourPeerEndpointResolver(),
        policy: any TransportPolicy = DefaultTransportPolicy(),
        httpSender: (any HTTPTransferSending)? = nil,
        activityGate: any TransferActivityGate = TransferActivityController()
    ) {
        self.mpc = mpc
        self.server = server
        self.endpointResolver = endpointResolver
        self.policy = policy
        self.activityGate = activityGate
        // Mini composition root for the transfer stack: the coordinator needs
        // the same MPC instance (for transferID-preserving fallback), the
        // same resolver (for endpoint refresh between retries), and the same
        // activity gate (so send + receive activities share one controller).
        // The upload client is the shared background-session instance so cold
        // background launches can reattach it before any facade exists.
        self.httpSender = httpSender ?? HTTPTransferSendCoordinator(
            uploadGate: BackgroundURLSessionUploadClient.shared,
            endpointResolver: endpointResolver,
            mpcFallback: mpc,
            activityGate: activityGate
        )
        mpc.delegate = self
        server.delegate = self
    }

    // MARK: - Receive-side Live Activity accounting

    /// Distinct received member-keys per transferID; a transfer's activity
    /// ends in success when the count reaches the expected total. Keyed
    /// member format: media "<index>" (logical items; LP videos excluded),
    /// files "<index>". Mixed-transport batches merge naturally because the
    /// MPC fallback preserves the transferID.
    private var receiveTallies: [String: (received: Set<Int>, total: Int)] = [:]

    private func trackReceiveStart(transferID: String, totalCount: Int, peer: Peer) {
        guard receiveTallies[transferID] == nil else { return }
        receiveTallies[transferID] = ([], totalCount)
        activityGate.startActivity(
            key: transferID, peerName: peer.displayName,
            direction: .receive, totalItems: totalCount
        )
    }

    private func trackReceiveItem(transferID: String, index: Int, totalCount: Int, peer: Peer) {
        // A start can be missed (out-of-order arrival); create the tally lazily.
        trackReceiveStart(transferID: transferID, totalCount: totalCount, peer: peer)
        guard var tally = receiveTallies[transferID] else { return }
        tally.received.insert(index)
        receiveTallies[transferID] = tally
        if tally.received.count >= tally.total {
            receiveTallies[transferID] = nil
            activityGate.updateActivity(key: transferID, progress: 1, completedItems: tally.total)
            activityGate.endActivity(key: transferID, outcome: .success)
        } else {
            activityGate.updateActivity(
                key: transferID,
                progress: Double(tally.received.count) / Double(max(1, tally.total)),
                completedItems: tally.received.count
            )
        }
    }

    // MARK: - NearbySessionService (control plane — always MPC)

    func start(displayName: String, deviceID: UUID) {
        mpc.start(displayName: displayName, deviceID: deviceID)
        server.start(deviceID: deviceID, displayName: displayName)
        endpointResolver.start()
        httpSender.setLocalIdentity(deviceID: deviceID, displayName: displayName)
        // Receives that never completed (suspension killed the listener while
        // the sender's retries also ran out) end honestly on the next launch.
        for transferID in receiveTallies.keys {
            activityGate.endActivity(key: transferID, outcome: .failure)
        }
        receiveTallies.removeAll()
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
        trackReceiveStart(transferID: transferID, totalCount: totalCount, peer: peer)
        delegate?.didStartReceivingMedia(transferID: transferID, totalCount: totalCount, from: peer)
    }

    func didReceiveMediaItem(
        transferID: String, index: Int, totalCount: Int,
        at url: URL, kind: MediaFileKind, fileName: String?,
        from peer: Peer
    ) {
        // LP companion videos share their still's logical index; only count
        // logical items against the total.
        if kind != .livePhotoVideo {
            trackReceiveItem(transferID: transferID, index: index, totalCount: totalCount, peer: peer)
        }
        delegate?.didReceiveMediaItem(
            transferID: transferID, index: index, totalCount: totalCount,
            at: url, kind: kind, fileName: fileName, from: peer
        )
    }

    func didStartReceivingFile(transferID: String, totalCount: Int, from peer: Peer) {
        trackReceiveStart(transferID: transferID, totalCount: totalCount, peer: peer)
        delegate?.didStartReceivingFile(transferID: transferID, totalCount: totalCount, from: peer)
    }

    func didReceiveFile(
        transferID: String, index: Int, totalCount: Int,
        at url: URL, name: String,
        from peer: Peer
    ) {
        trackReceiveItem(transferID: transferID, index: index, totalCount: totalCount, peer: peer)
        delegate?.didReceiveFile(
            transferID: transferID, index: index, totalCount: totalCount,
            at: url, name: name, from: peer
        )
    }
}

// MARK: - FileTransferServerDelegate (HTTP receptions → same delegate callbacks)

extension HybridNearbyService: FileTransferServerDelegate {
    // HTTP receptions funnel through the same forwarding methods the MPC
    // delegate path uses, so delegate fan-out and Live Activity accounting
    // live in exactly one place per event.

    func serverDidStartReceiving(item: IncomingTransferItemInfo, from peer: Peer) {
        switch item.payload {
        case .media:
            // Match the MPC path's behavior: LP companion videos never announce
            // a transfer start (MultipeerNearbyService skips .livePhotoVideo).
            guard item.kind != .livePhotoVideo else { return }
            didStartReceivingMedia(transferID: item.transferID, totalCount: item.total, from: peer)
        case .file:
            didStartReceivingFile(transferID: item.transferID, totalCount: item.total, from: peer)
        }
    }

    func serverDidReceive(item: IncomingTransferItemInfo, at url: URL, from peer: Peer) {
        switch item.payload {
        case .media:
            didReceiveMediaItem(
                transferID: item.transferID, index: item.index, totalCount: item.total,
                at: url, kind: item.kind, fileName: item.fileName, from: peer
            )
        case .file:
            didReceiveFile(
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
