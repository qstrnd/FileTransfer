import UIKit
import AVFoundation

struct ReceivedMediaItem: Identifiable {
    let id = UUID()
    let fileURL: URL
    let thumbnail: UIImage
    let isVideo: Bool
}

extension ReceivedMediaItem {
    static func load(from url: URL) async -> ReceivedMediaItem {
        let isVideo = ["mp4", "mov", "m4v", "avi"].contains(url.pathExtension.lowercased())
        let thumb: UIImage
        if isVideo {
            thumb = await videoThumbnail(at: url)
        } else {
            thumb = UIImage(contentsOfFile: url.path(percentEncoded: false))
                ?? UIImage(systemName: "photo.fill")
                ?? UIImage()
        }
        return ReceivedMediaItem(fileURL: url, thumbnail: thumb, isVideo: isVideo)
    }

    private static func videoThumbnail(at url: URL) async -> UIImage {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        if let result = try? await gen.image(at: .zero) {
            return UIImage(cgImage: result.image)
        }
        return UIImage(systemName: "video.fill") ?? UIImage()
    }
}
