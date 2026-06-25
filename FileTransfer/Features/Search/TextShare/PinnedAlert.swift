import SwiftUI
import UIKit

/// An invisible anchor that manages a sibling UIWindow for the received-text
/// alert, so it appears above any modal presentation (sheets, full-screen covers).
///
/// Unlike PinnedToast, this window is fully interactive — it hosts
/// ReceivedTextAlert with its backdrop, card, and action buttons.
struct PinnedAlert: UIViewRepresentable {
    let message: TransferMessage?
    let onDismiss: () -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let message {
            context.coordinator.show(message: message, onDismiss: onDismiss, anchoredTo: uiView)
        } else {
            context.coordinator.hide()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var window: UIWindow?
        private var host: UIHostingController<ReceivedTextAlert>?

        func show(message: TransferMessage, onDismiss: @escaping () -> Void, anchoredTo view: UIView) {
            let alertView = ReceivedTextAlert(message: message, onDismiss: onDismiss)

            if let host {
                // New message while alert is already on screen — swap content.
                host.rootView = alertView
                return
            }

            guard let scene = view.window?.windowScene else { return }

            let host = UIHostingController(rootView: alertView)
            host.view.backgroundColor = .clear

            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert - 1
            window.backgroundColor = .clear
            window.rootViewController = host
            window.isHidden = false
            window.alpha = 0

            UIView.animate(
                withDuration: 0.35, delay: 0,
                usingSpringWithDamping: 0.85, initialSpringVelocity: 0
            ) { window.alpha = 1 }

            self.window = window
            self.host = host
        }

        func hide() {
            guard let w = window else { return }
            // Stop accepting touches immediately so taps don't register during fade.
            w.isUserInteractionEnabled = false
            // Short grace period: the copy-toast inside ReceivedTextAlert fires 150ms
            // after onDismiss is called, so we wait for it to appear before fading.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                UIView.animate(withDuration: 0.3) { w.alpha = 0 } completion: { _ in
                    w.isHidden = true
                }
                self?.window = nil
                self?.host = nil
            }
        }
    }
}
