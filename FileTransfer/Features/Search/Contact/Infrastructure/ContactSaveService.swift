import UIKit

/// Shares a vCard as a .vcf file via UIActivityViewController.
/// The system share sheet offers "Add to Contacts" without requiring the app
/// to hold a contacts access entitlement.
@MainActor
final class ContactShareService {
    func share(vCardData: Data, senderName: String) {
        let baseName = senderName.isEmpty ? "contact" : senderName
        let fileName = "\(baseName).vcf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        guard (try? vCardData.write(to: tempURL)) != nil,
              let presenter = topViewController() else { return }

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX, y: presenter.view.bounds.midY,
                width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }
        presenter.present(activityVC, animated: true)
    }

    private func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
