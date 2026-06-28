import Foundation

/// Port for loading thumbnail image data from a local media file.
/// Returns raw Data so Domain stays free of UIKit. Presentation converts
/// Data → UIImage at the boundary.
protocol ThumbnailGate: Sendable {
    func thumbnail(for url: URL, isVideo: Bool) async -> Data?
}
