import Foundation

/// Port for generating downsampled previews of history attachment files.
/// Returns raw Data so Domain stays free of UIKit; Presentation converts Data → UIImage.
protocol HistoryThumbnailGate: Sendable {
    /// Returns JPEG thumbnail data for the file at `url`, or nil on failure.
    func thumbnail(for url: URL) async -> Data?
    /// Warms the cache for upcoming cells without blocking the caller.
    func prefetch(_ urls: [URL])
}
