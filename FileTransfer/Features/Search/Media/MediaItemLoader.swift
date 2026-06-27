import AVFoundation
import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// Loads a `MediaItem` from a `PHPickerResult`, preserving the original file format.
///
/// Images are loaded via `loadFileRepresentation` rather than `loadObject(ofClass:UIImage.self)`,
/// so the bytes sent over MPC are the original HEIC/JPEG/PNG/etc. file with no re-encoding.
enum MediaItemLoader {

    /// Image UTTypes tried in descending specificity. The first one the provider
    /// supports wins, giving us the original file format (e.g. HEIC) instead of
    /// a decoded/re-compressed copy.
    // nonisolated so tests (and nonisolated callers) can access without main-actor dispatch.
    nonisolated static let preferredImageTypes: [UTType] = [
        .heic, .jpeg, .png, .gif, .tiff, .webP, .image,
    ]

    // MARK: - Public

    static func load(from result: PHPickerResult) async -> MediaItem? {
        let provider = result.itemProvider
        // Check video first: some providers may conform to both movie and image.
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            return await loadVideo(from: provider)
        } else {
            return await loadImage(from: provider)
        }
    }

    /// Returns the best type identifier among `registeredIdentifiers` for preserving
    /// the original image format. `internal` (not `private`) so it can be unit-tested.
    nonisolated static func preferredImageTypeIdentifier(among registeredIdentifiers: [String]) -> String {
        for candidate in preferredImageTypes {
            let match = registeredIdentifiers.contains {
                UTType($0)?.conforms(to: candidate) == true
            }
            if match { return candidate.identifier }
        }
        return UTType.image.identifier
    }

    // MARK: - Private

    private static func loadImage(from provider: NSItemProvider) async -> MediaItem? {
        let typeID = preferredImageTypeIdentifier(among: provider.registeredTypeIdentifiers)
        return await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeID) { url, error in
                guard let srcURL = url, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                let ext = srcURL.pathExtension.isEmpty ? "jpg" : srcURL.pathExtension.lowercased()
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + "." + ext)
                do {
                    try FileManager.default.copyItem(at: srcURL, to: dest)
                } catch {
                    continuation.resume(returning: nil)
                    return
                }
                let image = UIImage(contentsOfFile: dest.path(percentEncoded: false)) ?? UIImage()
                let thumb = makeThumbnail(from: image, maxSize: 300)
                continuation.resume(returning: MediaItem(thumbnail: thumb, fileURL: dest, isVideo: false))
            }
        }
    }

    private static func loadVideo(from provider: NSItemProvider) async -> MediaItem? {
        let destURL: URL? = await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                guard let srcURL = url, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                let ext = srcURL.pathExtension.isEmpty ? "mov" : srcURL.pathExtension.lowercased()
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + "." + ext)
                do {
                    try FileManager.default.copyItem(at: srcURL, to: dest)
                    continuation.resume(returning: dest)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
        guard let destURL else { return nil }
        let thumb = await makeVideoThumbnail(at: destURL)
        return MediaItem(thumbnail: thumb, fileURL: destURL, isVideo: true)
    }

    // MARK: - Thumbnail helpers

    // nonisolated: UIGraphicsImageRenderer is thread-safe since iOS 10.
    nonisolated static func makeThumbnail(from image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(maxSize / size.width, maxSize / size.height)
        if scale >= 1 { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    private static func makeVideoThumbnail(at url: URL) async -> UIImage {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        if let result = try? await gen.image(at: .zero) {
            return UIImage(cgImage: result.image)
        }
        return UIImage(systemName: "video.fill") ?? UIImage()
    }
}
