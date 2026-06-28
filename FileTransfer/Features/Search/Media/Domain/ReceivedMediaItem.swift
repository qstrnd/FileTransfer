import Foundation

struct ReceivedMediaItem: Identifiable {
    let id = UUID()
    let fileURL: URL
    let isVideo: Bool

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.isVideo = ["mp4", "mov", "m4v", "avi"]
            .contains(fileURL.pathExtension.lowercased())
    }
}
