import Foundation

struct MediaItem: Identifiable {
    let id = UUID()
    let fileURL: URL
    let isVideo: Bool
    /// Non-nil when this is a Live Photo still; points to the companion `.mov`.
    let livePhotoVideoURL: URL?
    /// Base filename without extension, sourced from `NSItemProvider.suggestedName`.
    let fileName: String?
}
