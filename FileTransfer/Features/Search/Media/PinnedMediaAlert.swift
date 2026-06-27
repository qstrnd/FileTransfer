import SwiftUI
import UIKit

struct PinnedMediaAlert: UIViewRepresentable {
    let transfer: ReceivedMediaTransfer?
    let onDismiss: () -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let transfer {
            context.coordinator.show(transfer: transfer, onDismiss: onDismiss, anchoredTo: uiView)
        } else {
            context.coordinator.hide()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var window: UIWindow?
        private var host: UIHostingController<ReceivedMediaAlert>?

        func show(transfer: ReceivedMediaTransfer, onDismiss: @escaping () -> Void, anchoredTo view: UIView) {
            let alertView = ReceivedMediaAlert(transfer: transfer, onDismiss: onDismiss)

            if let host {
                host.rootView = alertView
                return
            }

            guard let scene = view.window?.windowScene else { return }

            let newHost = UIHostingController(rootView: alertView)
            newHost.view.backgroundColor = .clear

            let window = UIWindow(windowScene: scene)
            window.windowLevel = .normal
            window.backgroundColor = .clear
            window.rootViewController = newHost
            window.isHidden = false
            window.alpha = 0

            UIView.animate(
                withDuration: 0.35, delay: 0,
                usingSpringWithDamping: 0.85, initialSpringVelocity: 0
            ) { window.alpha = 1 }

            self.window = window
            self.host = newHost
        }

        func hide() {
            guard let w = window else { return }
            w.isUserInteractionEnabled = false
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
