struct Peer: Sendable, Identifiable, Hashable {
    let displayName: String
    nonisolated var id: String { displayName }
}

extension Peer {
    // Leading grapheme cluster (the emoji) from "🐟 Fantastic Fish" → "🐟"
    nonisolated var emojiComponent: String {
        displayName.isEmpty ? "?" : String(displayName.prefix(1))
    }

    // Everything after the first space from "🐟 Fantastic Fish" → "Fantastic Fish"
    nonisolated var nameComponent: String {
        guard let space = displayName.firstIndex(of: " ") else { return displayName }
        return String(displayName[displayName.index(after: space)...])
    }
}
