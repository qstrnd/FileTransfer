import SwiftUI
import UIKit

/// An invisible anchor that manages a sibling UIWindow for toast notifications
/// that must appear above any modal presentation (sheets, full-screen covers).
///
/// Because sheets are presented inside the main UIWindow's view hierarchy, a
/// second UIWindow at a higher windowLevel is the only reliable way to render
/// content above them. This view is embedded in the normal SwiftUI tree solely
/// to obtain a reference to the active UIWindowScene.
struct PinnedToast: UIViewRepresentable {
    let peer: Peer?

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let peer {
            context.coordinator.show(peer: peer, anchoredTo: uiView)
        } else {
            context.coordinator.hide()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var toastWindow: UIWindow?
        private var shownPeerID: Peer.ID?

        func show(peer: Peer, anchoredTo view: UIView) {
            guard peer.id != shownPeerID,
                  let scene = view.window?.windowScene else { return }
            hide()

            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert - 1
            window.backgroundColor = .clear
            window.isUserInteractionEnabled = false
            // Start above the screen so the capsule slides down into position.
            window.transform = CGAffineTransform(translationX: 0, y: -120)
            window.alpha = 0

            let host = UIHostingController(rootView: ToastCapsule(peer: peer))
            host.view.backgroundColor = .clear
            window.rootViewController = host
            window.isHidden = false

            UIView.animate(
                withDuration: 0.45, delay: 0,
                usingSpringWithDamping: 0.72, initialSpringVelocity: 0.4
            ) {
                window.transform = .identity
                window.alpha = 1
            }

            toastWindow = window
            shownPeerID = peer.id
        }

        func hide() {
            guard let w = toastWindow else { return }
            UIView.animate(
                withDuration: 0.3, delay: 0,
                usingSpringWithDamping: 1, initialSpringVelocity: 0
            ) {
                w.transform = CGAffineTransform(translationX: 0, y: -120)
                w.alpha = 0
            } completion: { _ in
                w.isHidden = true
            }
            toastWindow = nil
            shownPeerID = nil
        }
    }
}

// MARK: - Capsule content

private struct ToastCapsule: View {
    let peer: Peer

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(peer.emojiComponent)
                Text("\(peer.nameComponent) disconnected")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
