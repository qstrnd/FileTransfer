import Foundation
import Network
import OSLog

/// Local-network HTTP server that peers upload media/files to — the receiving
/// half of the hybrid data plane.
///
/// Listens on a dynamic TCP port and advertises it over Bonjour as
/// `_ftdata._tcp` with the device's stable UUID as the service instance name
/// (and in the TXT record), which is what `BonjourPeerEndpointResolver` on the
/// sending side matches against. Advertises only between `start()`/`stop()`,
/// mirroring the MPC advertiser lifecycle.
@MainActor
final class HTTPFileTransferServer: FileTransferServerGate {
    nonisolated private static let log = Logger(subsystem: "com.qstrnd.FileTransfer", category: "HTTPServer")
    static let bonjourServiceType = "_ftdata._tcp"

    weak var delegate: (any FileTransferServerDelegate)?

    private var listener: NWListener?
    private(set) var activeReceptionCount = 0

    // Handlers are registered/removed on the main actor; each handler's own
    // state lives on its connection queue.
    private var handlerRefs: [ObjectIdentifier: HTTPConnectionHandler] = [:]
    private let ledger = TransferReceptionLedger()

    // MARK: - FileTransferServerGate

    func start(deviceID: UUID, displayName: String) {
        guard listener == nil else { return }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        guard let listener = try? NWListener(using: parameters) else {
            Self.log.error("failed to create NWListener")
            return
        }

        let txt = NWTXTRecord(["deviceID": deviceID.uuidString, "name": displayName])
        listener.service = NWListener.Service(
            name: deviceID.uuidString,
            type: Self.bonjourServiceType,
            txtRecord: txt
        )

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                Self.log.info("listener ready on port \(listener.port?.rawValue ?? 0)")
            case .failed(let error):
                Self.log.error("listener failed: \(error.localizedDescription, privacy: .public)")
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor [weak self] in
                self?.accept(connection)
            }
        }

        listener.start(queue: .main)
        self.listener = listener
        Self.log.info("server starting — deviceID=\(deviceID, privacy: .public)")
    }

    func stop() {
        guard listener != nil || !handlerRefs.isEmpty else { return }
        Self.log.info("server stopping — cancelling \(self.handlerRefs.count) connection(s)")
        isDraining = false
        listener?.cancel()
        listener = nil
        for handler in handlerRefs.values { handler.cancel() }
        handlerRefs.removeAll()
        bodyStartedIDs.removeAll()
        setActiveReceptions(0)
        ledger.reset()
    }

    private var isDraining = false

    func drain() {
        guard !handlerRefs.isEmpty else {
            stop()
            return
        }
        Self.log.info("server draining — \(self.handlerRefs.count) reception(s) in flight")
        isDraining = true
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connections

    private func accept(_ connection: NWConnection) {
        let queue = DispatchQueue(label: "com.qstrnd.FileTransfer.http-conn")
        let handler = HTTPConnectionHandler(
            connection: connection,
            queue: queue,
            ledger: ledger,
            onBodyStart: { [weak self] started in
                Task { @MainActor [weak self] in
                    self?.handlerBodyStarted(started)
                }
            },
            onFinish: { [weak self] finished, outcome in
                Task { @MainActor [weak self] in
                    self?.handlerFinished(finished, outcome: outcome)
                }
            }
        )
        handlerRefs[ObjectIdentifier(handler)] = handler
        handler.start()
    }

    /// Handlers whose body phase began (in-flight count was incremented for them).
    private var bodyStartedIDs: Set<ObjectIdentifier> = []

    private func handlerBodyStarted(_ handler: HTTPConnectionHandler) {
        let id = ObjectIdentifier(handler)
        // A handler cancelled between its onBodyStart and this hop must not
        // re-increment after its finish already balanced the count.
        guard handlerRefs[id] != nil, bodyStartedIDs.insert(id).inserted else { return }
        setActiveReceptions(activeReceptionCount + 1)
    }

    private func handlerFinished(_ handler: HTTPConnectionHandler, outcome: HTTPConnectionHandler.Outcome) {
        let id = ObjectIdentifier(handler)
        guard handlerRefs.removeValue(forKey: id) != nil else { return }
        if bodyStartedIDs.remove(id) != nil {
            setActiveReceptions(max(0, activeReceptionCount - 1))
        }

        switch outcome {
        case .delivered(let item, let sender, let url, let firstOfTransfer):
            let peer = Peer(displayName: sender.displayName, deviceID: sender.deviceID)
            if firstOfTransfer {
                delegate?.serverDidStartReceiving(item: item, from: peer)
            }
            delegate?.serverDidReceive(item: item, at: url, from: peer)
        case .duplicate(let item):
            Self.log.info("duplicate upload answered 409 for \(item.transferID, privacy: .public)/\(item.index)")
        case .failed(let reason):
            Self.log.warning("reception ended without delivery: \(reason, privacy: .public)")
        }

        if isDraining && handlerRefs.isEmpty {
            Self.log.info("drain complete — server fully stopped")
            stop()
        }
    }

    private func setActiveReceptions(_ count: Int) {
        guard count != activeReceptionCount else { return }
        activeReceptionCount = count
        delegate?.serverReceptionActivityChanged(activeCount: count)
    }
}
