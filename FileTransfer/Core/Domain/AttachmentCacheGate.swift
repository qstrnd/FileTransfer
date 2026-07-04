import Foundation

/// Port for caching transfer-attachment files in a persistent local store.
/// Domain returns plain URLs and byte counts; Infrastructure owns the file operations.
protocol AttachmentCacheGate: Sendable {
    /// Copies `urls` into a per-record subdirectory and returns the new persistent URLs.
    /// `names[i]` is the desired filename for `urls[i]`; pass `nil` to let the cache
    /// generate a simple fallback name (e.g. "image.png", "document1.pdf").
    func cache(_ urls: [URL], names: [String?], forRecord id: UUID) async -> [URL]
    /// Sums the on-disk byte sizes of the given file URLs.
    func fileBytes(for urls: [URL]) -> Int64
    /// Removes all cached files for a record.
    func delete(recordID id: UUID)
}
