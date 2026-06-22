struct Peer: Sendable, Identifiable, Hashable {
    let displayName: String
    nonisolated var id: String { displayName }
}
