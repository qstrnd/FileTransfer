import Foundation

// MARK: - Record

/// An immutable record of a successful connection between this device and a remote peer.
struct ConnectionRecord: Codable, Equatable, Sendable {
    let deviceID: UUID
    /// Display name at the time of the last connection; stored for human-readable lookup.
    let displayName: String
    let lastConnected: Date
}

// MARK: - Protocol

/// Read/write access to the local history of past peer connections.
/// Implementations must be safe to call from the MainActor.
protocol ConnectionHistoryStore {
    func hasConnected(to deviceID: UUID) -> Bool
    func record(_ record: ConnectionRecord)
    func allRecords() -> [ConnectionRecord]
}

// MARK: - Convenience

extension ConnectionHistoryStore {
    /// Records a successful connection with `peer`, updating the timestamp if
    /// a record for this device already exists.
    func record(peer: Peer, connectedAt: Date = .now) {
        guard let id = peer.deviceID else { return }
        record(ConnectionRecord(
            deviceID: id,
            displayName: peer.displayName,
            lastConnected: connectedAt
        ))
    }
}
