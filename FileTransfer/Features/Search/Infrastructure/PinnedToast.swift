import SwiftUI
import UIKit

/// An invisible anchor that manages a sibling UIWindow for toast notifications
/// that must appear above any modal presentation (sheets, full-screen covers).
///
/// The window's frame is set in UIKit coordinates so the capsule always lands at
/// exactly the navigation-bar height — no dependence on SwiftUI safe-area layout.
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

            // UIKit gives the authoritative safe-area top regardless of whether
            // the separate UIHostingController inherits insets from the scene.
            let safeAreaTop = view.window?.safeAreaInsets.top ?? 50
            let screenWidth  = scene.screen.bounds.width
            // Tall enough to contain the capsule + room for shadow rendering.
            let windowHeight: CGFloat = 80

            let window = UIWindow(windowScene: scene)
            window.windowLevel   = .alert - 1
            window.backgroundColor = .clear
            window.isUserInteractionEnabled = false
            // Anchor the window frame at the safe-area boundary so the
            // capsule sits at the same height as a navigation-bar title.
            window.frame = CGRect(x: 0, y: safeAreaTop,
                                  width: screenWidth, height: windowHeight)
            // Begin above the screen (transform relative to the frame above).
            window.transform = CGAffineTransform(
                translationX: 0, y: -(safeAreaTop + windowHeight + 20))
            window.alpha = 0

            let host = UIHostingController(rootView: ToastCapsule(peer: peer))
            host.view.backgroundColor = .clear
            window.rootViewController = host
            window.isHidden = false

            // damping=1 — overdamped, slides in cleanly with no bounce.
            UIView.animate(
                withDuration: 0.4, delay: 0,
                usingSpringWithDamping: 1.0, initialSpringVelocity: 0.6
            ) {
                window.transform = .identity
                window.alpha = 1
            }

            toastWindow = window
            shownPeerID = peer.id
        }

        func hide() {
            guard let w = toastWindow else { return }
            // Slide back above the screen. The window's frame.minY == safeAreaTop,
            // so translating by -(maxY + 20) puts the bottom edge 20pt above y=0.
            let slideUp = -(w.frame.maxY + 20)
            UIView.animate(
                withDuration: 0.3, delay: 0,
                usingSpringWithDamping: 1, initialSpringVelocity: 0
            ) {
                w.transform = CGAffineTransform(translationX: 0, y: slideUp)
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
        HStack(spacing: 6) {
            Text(peer.emojiComponent)
            Text("\(peer.nameComponent) disconnected")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .glassEffect(in: Capsule())
        .shadow(color: .black.opacity(0.28), radius: 20, y: 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 6)
    }
}
