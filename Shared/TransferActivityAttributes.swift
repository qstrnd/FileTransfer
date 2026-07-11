import ActivityKit
import Foundation

/// Live Activity contract shared between the app (which starts/updates the
/// activity) and the TransferWidget extension (which renders it).
///
/// `nonisolated` so its ActivityAttributes/Codable conformances are usable
/// from any isolation (both targets build with default MainActor isolation,
/// and ActivityKit touches these values off the main actor).
nonisolated struct TransferActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        /// 0–1 across the whole batch.
        var progress: Double
        var completedItems: Int
        var phase: Phase

        enum Phase: String, Codable {
            case sending, receiving, success, failure
        }
    }

    /// Peer display name, e.g. "🦊 Bob".
    let peerName: String
    let direction: Direction
    let totalItems: Int
    /// Batch transferID — stable identity across updates.
    let transferKey: String

    enum Direction: String, Codable {
        case send, receive
    }
}
