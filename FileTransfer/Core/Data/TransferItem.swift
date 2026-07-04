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
    var typeRaw: String        // "text" | "photo" | "document" | "contact" | "file"
    var detail: String?
    /// JSON-encoded array of paths relative to Application Support for cached attachments.
    var attachmentURLsJSON: String?
    /// Combined byte count of all attachments; nil for non-file transfers.
    var fileBytes: Int64?
    /// JSON-encoded array of ContactInfo for contact transfers; nil for all other types.
    var contactsJSON: String?

    init(from record: TransferRecord) {
        self.id        = record.id
        self.peerEmoji = record.peerEmoji
        self.peerName  = record.peerName
        self.date      = record.date
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
        self.fileBytes = record.fileBytes

        // Store paths relative to Application Support so they survive container UUID changes.
        let appSupportBase = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let basePath = appSupportBase.path(percentEncoded: false)
        let relativePaths: [String] = record.attachmentURLs.map { url in
            let filePath = url.path(percentEncoded: false)
            guard filePath.hasPrefix(basePath) else { return url.absoluteString }
            var rel = String(filePath.dropFirst(basePath.count))
            if rel.hasPrefix("/") { rel = String(rel.dropFirst()) }
            return rel
        }
        if !relativePaths.isEmpty,
           let data = try? JSONEncoder().encode(relativePaths),
           let json = String(data: data, encoding: .utf8) {
            self.attachmentURLsJSON = json
        }

        if !record.contacts.isEmpty,
           let data = try? JSONEncoder().encode(record.contacts),
           let json = String(data: data, encoding: .utf8) {
            self.contactsJSON = json
        }
    }

    @MainActor var asRecord: TransferRecord {
        let direction: TransferDirection = directionRaw == "sent" ? .sent : .received
        let type: TransferType = switch typeRaw {
            case "photo":    .photo
            case "document": .document
            case "contact":  .contact
            case "file":     .file
            default:         .text
        }

        var attachmentURLs: [URL] = []
        if let json = attachmentURLsJSON,
           let data = json.data(using: .utf8),
           let strings = try? JSONDecoder().decode([String].self, from: data) {
            let appSupportBase = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            attachmentURLs = strings.compactMap { string -> URL? in
                if string.hasPrefix("file://") {
                    // Legacy absolute URL — re-anchor by extracting the
                    // TransferAttachments/… suffix and resolving against the live base.
                    guard let legacyURL = URL(string: string) else { return nil }
                    let legacyPath = legacyURL.path(percentEncoded: false)
                    if let range = legacyPath.range(of: "/TransferAttachments/") {
                        let suffix = String(legacyPath[range.lowerBound...].dropFirst())
                        return appSupportBase.appending(path: suffix, directoryHint: .notDirectory)
                    }
                    return legacyURL
                } else {
                    // Relative path — resolve against current Application Support.
                    return appSupportBase.appending(path: string, directoryHint: .notDirectory)
                }
            }
        }

        var contacts: [ContactInfo] = []
        if let json = contactsJSON,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([ContactInfo].self, from: data) {
            contacts = decoded
        }

        return TransferRecord(
            id: id, peerEmoji: peerEmoji, peerName: peerName,
            date: date, direction: direction, type: type, detail: detail,
            attachmentURLs: attachmentURLs, fileBytes: fileBytes,
            contacts: contacts
        )
    }
}
