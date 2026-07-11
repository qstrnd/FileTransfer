import Foundation

/// Metadata for one incoming HTTP-delivered transfer item, decoded from
/// request headers. Mirrors what `MediaTransferResource`/`FileTransferResource`
/// carry in MPC resource names so both transports feed the same delegate flow.
nonisolated struct IncomingTransferItemInfo: Sendable, Equatable {
    enum Payload: String, Sendable { case media, file }

    let transferID: String
    let index: Int
    let total: Int
    let payload: Payload
    /// Media only; `.regular` for files.
    let kind: MediaFileKind
    /// Original filename. For media: base name without extension (optional).
    /// For files: full name (required by the wire format).
    let fileName: String?
    /// Lowercase extension without dot; used to name the received temp file.
    let fileExtension: String
}

/// Receiving side of the HTTP data plane: a local server peers upload to.
@MainActor
protocol FileTransferServerGate: AnyObject {
    var delegate: (any FileTransferServerDelegate)? { get set }
    /// Starts listening on a dynamic port and advertises via Bonjour.
    func start(deviceID: UUID, displayName: String)
    /// Stops listening and cancels any in-flight receptions.
    func stop()
    /// Stops listening/advertising but lets in-flight receptions finish
    /// (used when the app backgrounds mid-reception under a background task);
    /// completes into a full stop once the last reception drains.
    func drain()
    var activeReceptionCount: Int { get }
}

@MainActor
protocol FileTransferServerDelegate: AnyObject {
    /// First item seen for a transferID (items can arrive out of order).
    func serverDidStartReceiving(item: IncomingTransferItemInfo, from peer: Peer)
    /// Item fully received and checksum-verified, stored at `url`.
    func serverDidReceive(item: IncomingTransferItemInfo, at url: URL, from peer: Peer)
    /// In-flight reception count changed (drives background task lifetime).
    func serverReceptionActivityChanged(activeCount: Int)
}
