import Foundation

nonisolated enum TransferActivityDirection: Sendable {
    case send, receive
}

nonisolated enum TransferActivityOutcome: Sendable {
    case success, failure
}

/// System-surface progress display for a transfer batch (Live Activity on
/// iOS). All methods are fire-and-forget: display is best-effort and must
/// never affect transfer behavior. Keyed by the batch transferID.
@MainActor
protocol TransferActivityGate: AnyObject {
    func startActivity(key: String, peerName: String, direction: TransferActivityDirection, totalItems: Int)
    func updateActivity(key: String, progress: Double, completedItems: Int)
    func endActivity(key: String, outcome: TransferActivityOutcome)
}
