import Foundation

struct ReceivedMediaItem: Identifiable {
    let id = UUID()
    let fileURL: URL
    let isVideo: Bool
    /// Non-nil when this is a Live Photo still; points to the companion `.mov`.
    let livePhotoVideoURL: URL?
    /// Resolved display filename including extension (e.g. "IMG_1234.heic" or
    /// "shared-photo-2026-06-28-abc123-1.heic"). Used when exporting to Files or Share.
    let fileName: String?

    var isLivePhoto: Bool { livePhotoVideoURL != nil }
}
