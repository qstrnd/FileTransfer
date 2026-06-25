import SwiftUI
import UIKit

/// Bridges `TransferCurtainViewController` into the SwiftUI view hierarchy.
///
/// Place this as a full-screen overlay on `SearchView`. The underlying UIKit
/// view controller manages its own positioning (two-detent sheet behavior)
/// inside its view, so no additional SwiftUI frame or offset is needed.
struct TransferCurtainView: UIViewControllerRepresentable {
    var viewModel: SearchViewModel

    // Called when the user taps a share action button.
    // The actual file-picking and transfer implementation is wired up later.
    var onShareText:     () -> Void
    var onSharePhoto:    () -> Void
    var onShareDocument: () -> Void
    var onShareContact:  () -> Void

    func makeUIViewController(context: Context) -> TransferCurtainViewController {
        TransferCurtainViewController()
    }

    func updateUIViewController(_ uiViewController: TransferCurtainViewController, context: Context) {
        uiViewController.update(selectedCount: viewModel.connectedPeers.count)
        // History will be wired to a TransferHistoryStore once that layer is built.
        #if DEBUG
        uiViewController.update(history: TransferRecord.previews)
        #else
        uiViewController.update(history: [])
        #endif

        // Refresh callbacks on every SwiftUI update so closures that capture
        // @State variables (like showDataExchange) always stay current.
        uiViewController.onShareText     = onShareText
        uiViewController.onSharePhoto    = onSharePhoto
        uiViewController.onShareDocument = onShareDocument
        uiViewController.onShareContact  = onShareContact
        uiViewController.onClearSelection = { viewModel.disconnectAll() }
    }
}
