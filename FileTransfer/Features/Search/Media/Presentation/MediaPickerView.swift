import PhotosUI
import SwiftUI

struct MediaPickerView: UIViewControllerRepresentable {
    let onComplete: @MainActor ([MediaItem]) -> Void
    let onCancel: @MainActor () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 0

        // 1. THE CRITICAL FIX: Prevent iOS from transcoding and breaking the Live Photo
        config.preferredAssetRepresentationMode = .current

        // 2. SIMPLIFIED FILTER: .images implicitly includes Live Photos.
        // You don't need to specify .livePhotos separately unless you ONLY want Live Photos.
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
                    if let item = await MediaItemLoader.load(from: result) {
                        items.append(item)
                    }
                }
                await MainActor.run { onComplete(items) }
            }
        }
    }
}
