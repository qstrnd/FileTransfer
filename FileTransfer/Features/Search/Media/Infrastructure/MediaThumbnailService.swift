import AVFoundation
import UIKit

/// Concrete ThumbnailGate: renders a scaled thumbnail and returns it as JPEG Data.
/// UIImage stays inside Infrastructure; the gate boundary only exposes Data.
final class MediaThumbnailService: ThumbnailGate {

    func thumbnail(for url: URL, isVideo: Bool) async -> Data? {
        let image: UIImage
        if isVideo {
            image = await videoThumbnail(at: url)
        } else {
            image = imageThumbnail(at: url)
        }
        return scaled(image, maxSize: 300).jpegData(compressionQuality: 0.8)
    }

    // MARK: - Private

    private func imageThumbnail(at url: URL) -> UIImage {
        UIImage(contentsOfFile: url.path(percentEncoded: false))
            ?? UIImage(systemName: "photo.fill")
            ?? UIImage()
    }

    private func videoThumbnail(at url: URL) async -> UIImage {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        if let result = try? await gen.image(at: .zero) {
            return UIImage(cgImage: result.image)
        }
        return UIImage(systemName: "video.fill") ?? UIImage()
    }

    // nonisolated: UIGraphicsImageRenderer is thread-safe since iOS 10.
    nonisolated private func scaled(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(maxSize / size.width, maxSize / size.height)
        if scale >= 1 { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
