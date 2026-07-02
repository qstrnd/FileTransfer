import Foundation

enum TransferDirection: Sendable {
    case sent, received
}

enum TransferType: Sendable {
    case text, photo, document, contact, file

    var systemImage: String {
        switch self {
        case .text:     "bubble.left"
        case .photo:    "photo"
        case .document: "doc"
        case .contact:  "person"
        case .file:     "doc.fill"
        }
    }

    var defaultDetail: String {
        switch self {
        case .text:     "Text message"
        case .photo:    "Photo"
        case .document: "Document"
        case .contact:  "Contact"
        case .file:     "File"
        }
    }
}

struct TransferRecord: Identifiable, Hashable, Sendable {
    let id: UUID
    /// At least one peer. For group transfers, all recipients are listed.
    let peers: [Peer]
    let date: Date
    let direction: TransferDirection
    let type: TransferType
    let detail: String?
    /// Persistent file:// URLs for cached attachment copies. Empty when not applicable.
    let attachmentURLs: [URL]
    /// Combined byte count of all attachments; nil for types with no files (e.g. text).
    let fileBytes: Int64?
    /// Non-empty only when type == .contact. Ordered list of contacts in this transfer.
    let contacts: [ContactInfo]

    nonisolated var peerEmoji: String { peers.first?.emojiComponent ?? "" }
    nonisolated var peerName: String { peers.first?.nameComponent ?? "" }

    init(
        id: UUID = UUID(),
        peers: [Peer],
        date: Date = .now,
        direction: TransferDirection,
        type: TransferType,
        detail: String? = nil,
        attachmentURLs: [URL] = [],
        fileBytes: Int64? = nil,
        contacts: [ContactInfo] = []
    ) {
        self.id = id
        self.peers = peers
        self.date = date
        self.direction = direction
        self.type = type
        self.detail = detail
        self.attachmentURLs = attachmentURLs
        self.fileBytes = fileBytes
        self.contacts = contacts
    }

    /// Convenience init for single-peer records — all existing call sites continue to compile.
    init(
        id: UUID = UUID(),
        peerEmoji: String,
        peerName: String,
        date: Date = .now,
        direction: TransferDirection,
        type: TransferType,
        detail: String? = nil,
        attachmentURLs: [URL] = [],
        fileBytes: Int64? = nil,
        contacts: [ContactInfo] = []
    ) {
        self.init(
            id: id,
            peers: [Peer(displayName: "\(peerEmoji) \(peerName)")],
            date: date,
            direction: direction,
            type: type,
            detail: detail,
            attachmentURLs: attachmentURLs,
            fileBytes: fileBytes,
            contacts: contacts
        )
    }

    static func == (lhs: TransferRecord, rhs: TransferRecord) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

#if DEBUG
extension TransferRecord {
    static let previews: [TransferRecord] = [
        TransferRecord(peerEmoji: "🦒", peerName: "Cunning Giraffe",
                       date: .now.addingTimeInterval(-120),
                       direction: .received, type: .photo, detail: "IMG_4821.HEIC",
                       fileBytes: 4_400_000),
        TransferRecord(peerEmoji: "🐱", peerName: "Sly Cat",
                       date: .now.addingTimeInterval(-3_600),
                       direction: .sent, type: .file, detail: "portfolio.pdf",
                       fileBytes: 1_800_000),
        TransferRecord(peerEmoji: "🐺", peerName: "Puffy Wolf",
                       date: .now.addingTimeInterval(-10_800),
                       direction: .sent, type: .text,
                       detail: "Hey — address for tomorrow: Hammer Steindamm 122, 2nd floor, call me when you arrive"),
    ]
}
#endif
