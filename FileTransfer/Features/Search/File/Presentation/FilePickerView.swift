import SwiftUI
import UniformTypeIdentifiers

struct FilePickerView: UIViewControllerRepresentable {
    let onComplete: @MainActor ([URL]) -> Void
    let onCancel: @MainActor () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete, onCancel: onCancel) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onComplete: @MainActor ([URL]) -> Void
        let onCancel: @MainActor () -> Void

        init(
            onComplete: @escaping @MainActor ([URL]) -> Void,
            onCancel: @escaping @MainActor () -> Void
        ) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            let onComplete = self.onComplete
            // Copy to a stable temp path so URLs survive the picker's temp directory cleanup.
            Task.detached {
                let tmp = FileManager.default.temporaryDirectory
                let copied = urls.map { src -> URL in
                    let dest = tmp.appendingPathComponent("fp_\(UUID().uuidString)_\(src.lastPathComponent)")
                    try? FileManager.default.removeItem(at: dest)
                    return (try? FileManager.default.copyItem(at: src, to: dest)) != nil ? dest : src
                }
                await MainActor.run { onComplete(copied) }
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            Task { @MainActor [onCancel] in onCancel() }
        }
    }
}
