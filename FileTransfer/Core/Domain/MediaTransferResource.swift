import Foundation

/// Encodes and decodes the MultipeerConnectivity resource name for a single media item.
///
/// Wire format: `media_<transferID>_<index>_<total>_<ext>`
/// - `transferID`: UUID with hyphens stripped (32 hex chars, no underscores)
/// - `index`: 0-based item position in the batch
/// - `total`: total items in the batch
/// - `ext`: lowercase file extension without dot (e.g. "heic", "jpg", "mp4")
struct MediaTransferResource: Sendable {
    nonisolated let transferID: String
    nonisolated let index: Int
    nonisolated let total: Int
    nonisolated let fileExtension: String

    // nonisolated so this computed property is callable from any concurrency context.
    nonisolated var name: String {
        "media_\(transferID)_\(index)_\(total)_\(fileExtension)"
    }

    // nonisolated on both inits: the struct may be inferred @MainActor because it is
    // first created inside @MainActor sendMedia, but the MCSession delegate callbacks
    // (nonisolated) also need to construct and read it.
    nonisolated init(transferID: String, index: Int, total: Int, fileExtension: String) {
        self.transferID = transferID
        self.index = index
        self.total = total
        self.fileExtension = fileExtension.isEmpty ? "bin" : fileExtension.lowercased()
    }

    /// Returns `nil` if `name` doesn't conform to the 5-component wire format.
    nonisolated init?(parsing name: String) {
        let parts = name.components(separatedBy: "_")
        guard parts.count == 5,
              parts[0] == "media",
              !parts[1].isEmpty,
              let idx = Int(parts[2]),
              let ttl = Int(parts[3]),
              !parts[4].isEmpty
        else { return nil }
        transferID = parts[1]
        index = idx
        total = ttl
        fileExtension = parts[4]
    }
}
