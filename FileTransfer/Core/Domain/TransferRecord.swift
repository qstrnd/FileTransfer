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
    let peerEmoji: String
    let peerName: String
    let date: Date
    let direction: TransferDirection
    let type: TransferType
    let detail: String?

    init(
        id: UUID = UUID(),
        peerEmoji: String,
        peerName: String,
        date: Date = .now,
        direction: TransferDirection,
        type: TransferType,
        detail: String? = nil
    ) {
        self.id = id
        self.peerEmoji = peerEmoji
        self.peerName = peerName
        self.date = date
        self.direction = direction
        self.type = type
        self.detail = detail
    }

    static func == (lhs: TransferRecord, rhs: TransferRecord) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

#if DEBUG
extension TransferRecord {
    // Static so UUIDs are created once and remain stable across SwiftUI update cycles.
    static let previews: [TransferRecord] = [
        TransferRecord(peerEmoji: "🦒", peerName: "Cunning Giraffe",
                       date: .now.addingTimeInterval(-120),
                       direction: .received, type: .photo, detail: "Photo"),
        TransferRecord(peerEmoji: "🐱", peerName: "Sly Cat",
                       date: .now.addingTimeInterval(-3_600),
                       direction: .sent, type: .document, detail: "portfolio.pdf"),
        TransferRecord(peerEmoji: "🐺", peerName: "Puffy Wolf",
                       date: .now.addingTimeInterval(-10_800),
                       direction: .sent, type: .text, detail: "On my way 👍"),
    ]
}
#endif
