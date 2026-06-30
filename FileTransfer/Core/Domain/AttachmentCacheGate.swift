import Foundation

/// Port for caching transfer-attachment files in a persistent local store.
/// Domain returns plain URLs and byte counts; Infrastructure owns the file operations.
protocol AttachmentCacheGate: Sendable {
    /// Copies `urls` into a subdirectory keyed by `id` and returns the new persistent URLs.
    func cache(_ urls: [URL], forRecord id: UUID) async -> [URL]
    /// Sums the on-disk byte sizes of the given file URLs.
    func fileBytes(for urls: [URL]) -> Int64
    /// Removes all cached files for a record.
    func delete(recordID id: UUID)
}
