import UIKit

/// Handles saving or sharing received files using the system Files picker and share sheet.
@MainActor
final class FileSaveService {

    func saveToFiles(_ files: [ReceivedFile]) {
        let urls = files.map(\.url)
        guard !urls.isEmpty, let presenter = topViewController() else { return }
        let picker = UIDocumentPickerViewController(forExporting: urls, asCopy: true)
        presenter.present(picker, animated: true)
    }

    func share(_ files: [ReceivedFile]) {
        guard !files.isEmpty, let presenter = topViewController() else { return }
        let activityItems: [Any] = files.map { $0.url as Any }
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

    private func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return nil }
        var presenter = rootVC
        while let presented = presenter.presentedViewController { presenter = presented }
        return presenter
    }
}
