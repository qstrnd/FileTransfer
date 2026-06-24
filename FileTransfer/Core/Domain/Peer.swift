import Foundation

struct Peer: Sendable, Identifiable, Hashable {
    let displayName: String
    /// Stable UUID advertised by the remote device via MPC discoveryInfo.
    /// `nil` when connecting to a legacy peer that doesn't include one.
    let deviceID: UUID?

    nonisolated var id: String { displayName }

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
}
