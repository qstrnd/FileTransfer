struct Peer: Identifiable, Hashable {
    let displayName: String
    var id: String { displayName }
}
