import Foundation

/// Orchestrates a batch of media/file uploads to one peer over HTTP:
/// checksums, per-item retries, mid-batch MPC fallback, and honest terminal
/// outcomes. The facade routes here when `TransportPolicy` picks HTTP.
///
/// `onItemCompleted` fires exactly once per file with its terminal outcome,
/// regardless of which transport ultimately carried it.
@MainActor
protocol HTTPTransferSending: AnyObject {
    /// Local identity stamped into upload headers; set when the session starts.
    func setLocalIdentity(deviceID: UUID, displayName: String)

    /// True when no batches are in flight. Together with `onIdle` this lets
    /// the facade defer session teardown until outgoing transfers finish.
    var isIdle: Bool { get }
    /// Fired once each time the last in-flight batch reaches a terminal state.
    var onIdle: (@MainActor () -> Void)? { get set }

    /// Starts the batch and synchronously returns one `Progress` per file
    /// (the same objects the existing send UI polls, surviving retries and
    /// transport fallback).
    func sendMedia(
        _ files: [MediaFileToSend], to peer: Peer, endpoint: PeerEndpoint,
        onItemCompleted: @escaping @MainActor (Result<Void, TransferSendError>) -> Void
    ) -> [Progress]

    func sendFiles(
        _ files: [FileToSend], to peer: Peer, endpoint: PeerEndpoint,
        onItemCompleted: @escaping @MainActor (Result<Void, TransferSendError>) -> Void
    ) -> [Progress]
}

/// The slice of the MPC service the coordinator needs for mid-batch fallback:
/// transferID-preserving bulk sends, so the receiver keeps accumulating the
/// batch's remaining items under the ID the HTTP-delivered ones already used.
@MainActor
protocol MPCBatchFallback: AnyObject {
    func sendMedia(_ files: [MediaFileToSend], to peer: Peer, transferID: String, onItemCompleted: @escaping @MainActor (Result<Void, TransferSendError>) -> Void) -> [Progress]
    func sendFiles(_ files: [FileToSend], to peer: Peer, transferID: String, onItemCompleted: @escaping @MainActor (Result<Void, TransferSendError>) -> Void) -> [Progress]
}
