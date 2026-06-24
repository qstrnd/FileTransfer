import Foundation
import MultipeerConnectivity

/// Tracks peers discovered by the MPC browser.
///
/// **Ownership rule** (enforced by the API surface):
/// Entries are added by `peerFound(_:deviceID:)` and removed by
/// `peerLost(displayName:)` or `reset()`.
/// Session state changes — including disconnect — have **no corresponding
/// mutation method**. This is intentional: a session disconnect means the
/// link is severed, not that the peer left discovery range. The `MCPeerID`
/// remains valid for re-invitation, so reconnection works without a full
/// stop/start cycle.
struct PeerRegistry {
    // nonisolated(unsafe): accessed from nonisolated MPC callbacks.
    // Safety is provided by the caller — MultipeerNearbyService declares
    // its `registry` as nonisolated(unsafe) and documents the ordering guarantee.
    nonisolated(unsafe) private var peerIDs: [String: MCPeerID] = [:]
    nonisolated(unsafe) private var deviceIDs: [String: UUID] = [:]

    // All members are nonisolated: PeerRegistry is a pure value type with no
    // actor-isolated state, so it can safely be mutated from nonisolated
    // MPC delegate callbacks (which run on a background thread managed by MPC).

    nonisolated init() {}

    // MARK: - Mutations (browser events only)

    nonisolated mutating func peerFound(_ peerID: MCPeerID, deviceID: UUID?) {
        peerIDs[peerID.displayName] = peerID
        if let id = deviceID { deviceIDs[peerID.displayName] = id }
    }

    nonisolated mutating func peerLost(displayName: String) {
        peerIDs.removeValue(forKey: displayName)
        deviceIDs.removeValue(forKey: displayName)
    }

    /// Clears all entries. Called by `stop()` only.
    nonisolated mutating func reset() {
        peerIDs = [:]
        deviceIDs = [:]
    }

    // MARK: - Lookups

    nonisolated func mcPeerID(for displayName: String) -> MCPeerID? {
        peerIDs[displayName]
    }

    nonisolated func deviceID(for displayName: String) -> UUID? {
        deviceIDs[displayName]
    }

    nonisolated func peer(for peerID: MCPeerID) -> Peer {
        Peer(displayName: peerID.displayName, deviceID: deviceIDs[peerID.displayName])
    }

    nonisolated var isEmpty: Bool { peerIDs.isEmpty }
    nonisolated var count: Int { peerIDs.count }
}
