import Foundation

/// Terminal failure for a single outgoing transfer item, after all transports
/// and retries have been exhausted. Carried to the UI through the
/// `onItemCompleted` closure of `sendMedia`/`sendFiles` so failures are
/// reported honestly instead of being silently logged.
enum TransferSendError: Error, Sendable, Equatable {
    /// No route to the peer: HTTP endpoint unresolved and MPC session unavailable.
    case peerUnreachable
    /// TCP/connection-level failure talking to the peer's server.
    case connectionFailed(String)
    /// The peer's server rejected the upload with a non-retryable HTTP status.
    case serverRejected(status: Int)
    /// The uploaded bytes did not match the declared SHA-256 after retries.
    case checksumMismatch
    case timedOut
    case cancelled
    /// The MPC data-plane send failed (also used when MPC was the primary transport).
    case multipeerFailed(String)
    /// The source file disappeared before it could be read/uploaded.
    case sourceFileMissing
}

extension TransferSendError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .peerUnreachable:            "Device is unreachable"
        case .connectionFailed:           "Connection to the device failed"
        case .serverRejected(let status): "Device rejected the transfer (\(status))"
        case .checksumMismatch:           "Transfer arrived corrupted"
        case .timedOut:                   "Transfer timed out"
        case .cancelled:                  "Transfer cancelled"
        case .multipeerFailed:            "Nearby connection failed"
        case .sourceFileMissing:          "File is no longer available"
        }
    }
}
