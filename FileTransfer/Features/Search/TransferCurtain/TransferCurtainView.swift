import SwiftUI
import UIKit

/// Bridges `TransferCurtainViewController` into the SwiftUI view hierarchy.
///
/// Place this as a full-screen overlay on `SearchView`. The underlying UIKit
/// view controller manages its own positioning (two-detent sheet behavior)
/// inside its view, so no additional SwiftUI frame or offset is needed.
struct TransferCurtainView: UIViewControllerRepresentable {
    var viewModel: SearchViewModel
    var disableScrim: Bool = false
    /// Portrait-only: when set the sheet is centred at this fixed width (iPad).
    /// Nil keeps the default full-width behaviour (iPhone).
    var maxSheetWidth: CGFloat? = nil

    // Called when the user taps a share action button.
    var onShareText:       () -> Void
    var onSharePhoto:      () -> Void
    var onShareFile:       () -> Void
    var onShareContact:    () -> Void
    var onSharePasteboard: () -> Void

    func makeUIViewController(context: Context) -> TransferCurtainViewController {
        let vc = TransferCurtainViewController()
        vc.maxSheetWidth = maxSheetWidth
        return vc
    }

    func updateUIViewController(_ uiViewController: TransferCurtainViewController, context: Context) {
        uiViewController.update(selectedCount: viewModel.connectedPeers.count)
        uiViewController.update(historyDisabled: !viewModel.isHistoryEnabled)
        uiViewController.update(history: viewModel.transferHistory)
        uiViewController.setScrimEnabled(!disableScrim)

        // Refresh callbacks on every SwiftUI update so closures that capture
        // @State variables (like showFilePicker) always stay current.
        uiViewController.onShareText       = onShareText
        uiViewController.onSharePhoto      = onSharePhoto
        uiViewController.onShareFile       = onShareFile
        uiViewController.onShareContact    = onShareContact
        uiViewController.onSharePasteboard = onSharePasteboard
        uiViewController.onClearSelection = { viewModel.disconnectAll() }
        uiViewController.thumbnailGate   = viewModel.historyThumbnailGate
        uiViewController.onDeleteRecord  = { viewModel.deleteHistoryRecord($0) }
        uiViewController.onSendToDevices = { viewModel.resendFromHistory($0) }
    }
}
