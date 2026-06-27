import SwiftUI
import UIKit

/// UIWindow host for SendingMediaAlert. Follows the same pattern as
/// PinnedInvitationAlert: the window is kept alive while the transfer is
/// active and its content is updated via host.rootView so that SwiftUI's
/// own animations (progress → checkmark) play smoothly inside it.
struct PinnedSendingAlert: UIViewRepresentable {
    let transfer: OutgoingMediaTransfer?
    let onAbort: () -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.update(transfer: transfer, onAbort: onAbort, anchoredTo: uiView)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var window: UIWindow?
        private var host: UIHostingController<SendingMediaAlert>?
        private var pendingHide: DispatchWorkItem?

        func update(
            transfer: OutgoingMediaTransfer?,
            onAbort: @escaping () -> Void,
            anchoredTo view: UIView
        ) {
            let alertView = SendingMediaAlert(transfer: transfer, onAbort: onAbort)

            if let host {
                host.rootView = alertView
                window?.isUserInteractionEnabled = transfer != nil

                if transfer != nil {
                    pendingHide?.cancel()
                    pendingHide = nil
                    window?.isHidden = false
                    UIView.animate(withDuration: 0.2) { self.window?.alpha = 1 }
                } else {
                    scheduleHide()
                }
                return
            }

            guard transfer != nil, let scene = view.window?.windowScene else { return }

            let host = UIHostingController(rootView: alertView)
            host.view.backgroundColor = .clear

            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert - 1
            window.backgroundColor = .clear
            window.rootViewController = host
            window.alpha = 0
            window.isHidden = false

            UIView.animate(withDuration: 0.3) { window.alpha = 1 }

            self.window = window
            self.host = host
        }

        private func scheduleHide() {
            pendingHide?.cancel()
            let item = DispatchWorkItem { [weak self] in
                UIView.animate(withDuration: 0.3) { self?.window?.alpha = 0 } completion: { _ in
                    self?.window?.isHidden = true
                }
            }
            pendingHide = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: item)
        }
    }
}
