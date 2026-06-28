import Foundation

/// A single file entry in a batch media transfer, carrying the metadata
/// needed to encode the wire-format resource name.
struct MediaFileToSend: Sendable {
    let url: URL
    /// Position of the user-visible item this file belongs to (0-based).
    let logicalIndex: Int
    /// Number of user-visible items in this transfer (not file count).
    let logicalTotal: Int
    let kind: MediaFileKind
    /// Base filename without extension (e.g. "IMG_1234"). Nil for LP companion videos.
    let suggestedName: String?
}

enum MediaFileKind: String, Sendable {
    case regular
    case livePhotoStill = "lp"
    case livePhotoVideo = "lpv"
}
