import Photos
import UIKit

/// Concrete MediaSavingGate: persists or shares received media using Photos and UIKit.
@MainActor
final class MediaSaveService: MediaSavingGate {

    func saveToGallery(_ items: [ReceivedMediaItem]) async -> Bool {
        let fileInfos: [(url: URL, isVideo: Bool)] = items.map { ($0.fileURL, $0.isVideo) }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Crash on Xcode 26.4.1, iOS 26.4 if the async variant is used.
                PHPhotoLibrary.shared().performChanges {
                    for (url, isVideo) in fileInfos {
                        if isVideo {
                            let _ = PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
                        } else {
                            let _ = PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: url)
                        }
                    }
                } completionHandler: { success, _ in
                    continuation.resume(returning: success)
                }
            }
        }
    }

    func saveToFiles(_ items: [ReceivedMediaItem]) {
        let urls = items.map(\.fileURL)
        guard !urls.isEmpty, let presenter = topViewController() else { return }
        let picker = UIDocumentPickerViewController(forExporting: urls, asCopy: true)
        presenter.present(picker, animated: true)
    }

    func share(_ items: [ReceivedMediaItem]) {
        guard !items.isEmpty, let presenter = topViewController() else { return }
        let activityItems: [Any] = items.map { item in
            item.isVideo
                ? item.fileURL as Any
                : (UIImage(contentsOfFile: item.fileURL.path(percentEncoded: false)) ?? UIImage()) as Any
        }
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

    private func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return nil }
        var presenter = rootVC
        while let presented = presenter.presentedViewController { presenter = presented }
        return presenter
    }
}
