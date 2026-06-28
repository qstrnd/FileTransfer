import UIKit

/// Port for loading a displayable thumbnail from a local media file.
///
/// UIImage is considered a platform primitive for iOS-only modules and
/// is therefore acceptable in gate signatures. See AGENTS.md §Gates.
protocol ThumbnailGate: Sendable {
    func thumbnail(for url: URL, isVideo: Bool) async -> UIImage
}
