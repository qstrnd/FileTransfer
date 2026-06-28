import Foundation

struct MediaItem: Identifiable {
    let id = UUID()
    let fileURL: URL
    let isVideo: Bool
}
