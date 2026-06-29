import SwiftData
import Foundation

/// Persistent backing store for a single file/text transfer event.
/// Enums are stored as raw strings to avoid Swift 6 actor-isolation issues
/// that arise when RawRepresentable enum conformances interact with SwiftData.
@Model
final class TransferItem {
    var id: UUID
    var peerEmoji: String
    var peerName: String
    var date: Date
    var directionRaw: String   // "sent" | "received"
    var typeRaw: String        // "text" | "photo" | "document" | "contact"
    var detail: String?

    init(from record: TransferRecord) {
        self.id        = record.id
        self.peerEmoji = record.peerEmoji
        self.peerName  = record.peerName
        self.date      = record.date
        // Use switch (pattern matching) instead of == to avoid the @MainActor-isolated
        // Equatable conformance that SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor produces.
        switch record.direction {
        case .sent:     self.directionRaw = "sent"
        case .received: self.directionRaw = "received"
        }
        switch record.type {
        case .text:     self.typeRaw = "text"
        case .photo:    self.typeRaw = "photo"
        case .document: self.typeRaw = "document"
        case .contact:  self.typeRaw = "contact"
        case .file:     self.typeRaw = "file"
        }
        self.detail = record.detail
    }

    // @MainActor required: TransferRecord.init is @MainActor-isolated by default.
    @MainActor var asRecord: TransferRecord {
        let direction: TransferDirection = directionRaw == "sent" ? .sent : .received
        let type: TransferType = switch typeRaw {
            case "photo":    .photo
            case "document": .document
            case "contact":  .contact
            case "file":     .file
            default:         .text
        }
        return TransferRecord(
            id: id, peerEmoji: peerEmoji, peerName: peerName,
            date: date, direction: direction, type: type, detail: detail
        )
    }
}
