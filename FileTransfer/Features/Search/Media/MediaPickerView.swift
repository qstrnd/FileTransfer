import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AVFoundation

struct MediaPickerView: UIViewControllerRepresentable {
    let onComplete: @MainActor ([MediaItem]) -> Void
    let onCancel: @MainActor () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 0
        config.filter = .any(of: [.images, .videos])
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete, onCancel: onCancel) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onComplete: @MainActor ([MediaItem]) -> Void
        let onCancel: @MainActor () -> Void

        init(
            onComplete: @escaping @MainActor ([MediaItem]) -> Void,
            onCancel: @escaping @MainActor () -> Void
        ) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                Task { @MainActor [onCancel] in onCancel() }
                return
            }
            let onComplete = self.onComplete
            Task {
                var items: [MediaItem] = []
                for result in results {
                    if let item = await Self.loadItem(from: result) {
                        items.append(item)
                    }
                }
                await MainActor.run { onComplete(items) }
            }
        }

        private static nonisolated func loadItem(from result: PHPickerResult) async -> MediaItem? {
            let provider = result.itemProvider
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                return await loadImage(from: provider)
            } else if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                return await loadVideo(from: provider)
            }
            return nil
        }

        private static nonisolated func loadImage(from provider: NSItemProvider) async -> MediaItem? {
            await withCheckedContinuation { continuation in
                provider.loadObject(ofClass: UIImage.self) { obj, error in
                    guard let image = obj as? UIImage, error == nil else {
                        continuation.resume(returning: nil)
                        return
                    }
                    guard let data = image.jpegData(compressionQuality: 0.85) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString + ".jpg")
                    do {
                        try data.write(to: url)
                    } catch {
                        continuation.resume(returning: nil)
                        return
                    }
                    let thumb = makeThumbnail(from: image, maxSize: 300)
                    continuation.resume(returning: MediaItem(thumbnail: thumb, fileURL: url, isVideo: false))
                }
            }
        }

        private static nonisolated func loadVideo(from provider: NSItemProvider) async -> MediaItem? {
            let destURL: URL? = await withCheckedContinuation { continuation in
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    guard let srcURL = url, error == nil else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let ext = srcURL.pathExtension.isEmpty ? "mov" : srcURL.pathExtension
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

        private static nonisolated func makeThumbnail(from image: UIImage, maxSize: CGFloat) -> UIImage {
            let size = image.size
            guard size.width > 0, size.height > 0 else { return image }
            let scale = min(maxSize / size.width, maxSize / size.height)
            if scale >= 1 { return image }
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        }

        private static nonisolated func makeVideoThumbnail(at url: URL) async -> UIImage {
            let asset = AVURLAsset(url: url)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            if let result = try? await gen.image(at: .zero) {
                return UIImage(cgImage: result.image)
            }
            return UIImage(systemName: "video.fill") ?? UIImage()
        }
    }
}
