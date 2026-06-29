import Foundation

struct Peer: Sendable, Identifiable, Hashable {
    let displayName: String
    /// Stable UUID advertised by the remote device via MPC discoveryInfo.
    /// `nil` when connecting to a legacy peer that doesn't include one.
    let deviceID: UUID?

    nonisolated var id: String { displayName }

    // Equality and hashing are keyed on displayName only, consistent with `id`.
    // This ensures that Peer(displayName: X, deviceID: nil) — produced by the
    // advertiser callback before the browser fires foundPeer — and
    // Peer(displayName: X, deviceID: someUUID) — produced after foundPeer — are
    // treated as the same peer for peerStates dictionary lookups.
    nonisolated static func == (lhs: Peer, rhs: Peer) -> Bool { lhs.displayName == rhs.displayName }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(displayName) }

    nonisolated init(displayName: String, deviceID: UUID? = nil) {
        self.displayName = displayName
        self.deviceID = deviceID
    }
}

// MARK: - Display name parsing

extension Peer {
    /// Leading grapheme cluster (emoji) from "🐟 Fantastic Fish" → "🐟"
    nonisolated var emojiComponent: String {
        displayName.isEmpty ? "?" : String(displayName.prefix(1))
    }

    /// Everything after the first space: "🐟 Fantastic Fish" → "Fantastic Fish"
    nonisolated var nameComponent: String {
        guard let space = displayName.firstIndex(of: " ") else { return displayName }
        return String(displayName[displayName.index(after: space)...])
    }

    /// Splits any "🐟 Fantastic Fish"-formatted string into (emoji, name).
    /// Used when a peer is known only by their display-name string rather than a `Peer` value.
    static func parseDisplayName(_ raw: String) -> (emoji: String, name: String) {
        let emoji = raw.isEmpty ? "?" : String(raw.prefix(1))
        guard let space = raw.firstIndex(of: " ") else { return (emoji, raw) }
        return (emoji, String(raw[raw.index(after: space)...]))
    }
}
