import SwiftUI
import UIKit

/// An invisible anchor that lifts InvitationAlert into a sibling UIWindow so
/// it appears above sheets and full-screen covers.
///
/// Unlike PinnedAlert, the window is kept alive after peer → nil so
/// InvitationAlert's own spring exit animation can play before the window hides.
struct PinnedInvitationAlert: UIViewRepresentable {
    let peer: Peer?
    let onAccept: () -> Void
    let onDecline: () -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.update(
            peer: peer, onAccept: onAccept, onDecline: onDecline,
            anchoredTo: uiView
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var window: UIWindow?
        private var host: UIHostingController<InvitationAlert>?
        private var pendingHide: DispatchWorkItem?

        func update(
            peer: Peer?,
            onAccept: @escaping () -> Void,
            onDecline: @escaping () -> Void,
            anchoredTo view: UIView
        ) {
            let alertView = InvitationAlert(peer: peer, onAccept: onAccept, onDecline: onDecline)

            if let host {
                host.rootView = alertView
                window?.isUserInteractionEnabled = peer != nil

                if peer != nil {
                    pendingHide?.cancel()
                    pendingHide = nil
                    window?.isHidden = false
                    UIView.animate(withDuration: 0.2) { self.window?.alpha = 1 }
                } else {
                    scheduleHide()
                }
                return
            }

            guard peer != nil, let scene = view.window?.windowScene else { return }

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
                UIView.animate(withDuration: 0.2) { self?.window?.alpha = 0 } completion: { _ in
                    self?.window?.isHidden = true
                }
            }
            pendingHide = item
            // InvitationAlert's exit spring is 0.3s; wait a bit longer to be safe.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: item)
        }
    }
}
