import Photos
import UIKit

/// Concrete MediaSavingGate: persists or shares received media using Photos and UIKit.
@MainActor
final class MediaSaveService: MediaSavingGate {

    func saveToGallery(_ items: [ReceivedMediaItem]) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Crash on Xcode 26.4.1, iOS 26.4 if the async variant is used.
                PHPhotoLibrary.shared().performChanges {
                    for item in items {
                        if let lpVideoURL = item.livePhotoVideoURL {
                            // Reconstruct a Live Photo asset in the gallery.
                            let request = PHAssetCreationRequest.forAsset()
                            request.addResource(with: .photo, fileURL: item.fileURL, options: nil)
                            request.addResource(with: .pairedVideo, fileURL: lpVideoURL, options: nil)
                        } else if item.isVideo {
                            let _ = PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: item.fileURL)
                        } else {
                            let _ = PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: item.fileURL)
                        }
                    }
                } completionHandler: { success, _ in
                    continuation.resume(returning: success)
                }
            }
        }
    }

    func saveToFiles(_ items: [ReceivedMediaItem]) {
        // Rename temp files to meaningful names before presenting the export picker.
        let exportURLs: [URL] = items.flatMap { namedURLs(for: $0) }
        guard !exportURLs.isEmpty, let presenter = topViewController() else { return }
        let picker = UIDocumentPickerViewController(forExporting: exportURLs, asCopy: true)
        presenter.present(picker, animated: true)
    }

    func share(_ items: [ReceivedMediaItem]) {
        guard !items.isEmpty, let presenter = topViewController() else { return }
        // Share as file URLs (preserves metadata, works well with AirDrop).
        let activityItems: [Any] = items.flatMap { namedURLs(for: $0) as [Any] }
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }
        presenter.present(activityVC, animated: true)
    }

    // MARK: - Private

    /// Returns file URLs named after `item.fileName` (copying to a new temp path if needed).
    /// For Live Photos returns [still, companionVideo].
    private func namedURLs(for item: ReceivedMediaItem) -> [URL] {
        var result: [URL] = []
        result.append(renamed(item.fileURL, to: item.fileName))
        if let lp = item.livePhotoVideoURL {
            // Keep the companion video next to the still with the same base name.
            let lpName = item.fileName.map { base -> String in
                let baseName = (base as NSString).deletingPathExtension
                return "\(baseName).mov"
            }
            result.append(renamed(lp, to: lpName))
        }
        return result
    }

    /// Copies `url` to a temp file named `name` (if non-nil) and returns the new URL.
    /// Returns `url` unchanged if name is nil or the copy fails.
    private func renamed(_ url: URL, to name: String?) -> URL {
        guard let name else { return url }
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        // Overwrite if a previous rename already placed a file there.
        try? FileManager.default.removeItem(at: dest)
        if (try? FileManager.default.copyItem(at: url, to: dest)) != nil { return dest }
        return url
    }

    private func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return nil }
        var presenter = rootVC
        while let presented = presenter.presentedViewController { presenter = presented }
        return presenter
    }
}
