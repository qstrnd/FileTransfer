import UIKit

struct MediaItem: Identifiable {
    let id = UUID()
    let thumbnail: UIImage
    let fileURL: URL
    let isVideo: Bool
}
