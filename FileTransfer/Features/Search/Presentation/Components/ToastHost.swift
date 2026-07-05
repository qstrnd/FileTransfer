import SwiftUI
import UIKit

/// Renders whatever `ToastCenter.shared` is currently showing, anchored just
/// below the safe area like a navigation-bar title.
///
/// Each distinct toast (a new `id`) is presented in a brand-new `UIWindow` —
/// presentations are never reused or mutated in place. The window sits at the
/// highest level in the app (`.toast`) and passes every gesture straight
/// through to whatever is underneath, so a toast never blocks interaction.
///
/// Add exactly one `ToastHost()` to the view hierarchy (e.g. `.background(ToastHost())`
/// on the root view); every `ToastPresenting.show(...)` call anywhere in the
/// app is rendered by this single host.
struct ToastHost: UIViewRepresentable {
    // Reading `ToastCenter.shared.current` here creates the Observation
    // dependency that makes SwiftUI call `updateUIView` whenever a toast changes.
    private var current: ToastCenter.Toast? { ToastCenter.shared.current }

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let current {
            context.coordinator.show(current, anchoredTo: uiView)
        } else {
            context.coordinator.hide()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var window: UIWindow?
        private var host: UIHostingController<AnyView>?
        private var shownID: AnyHashable?

        func show(_ toast: ToastCenter.Toast, anchoredTo view: UIView) {
            // Same toast still showing (e.g. a progress capsule ticking up) —
            // update its content in place rather than restarting the window.
            if let host, shownID == toast.id {
                host.rootView = toast.content
                return
            }

            guard let scene = view.window?.windowScene else { return }
            hide()

            let safeAreaTop = view.window?.safeAreaInsets.top ?? 50
            let screenWidth = scene.screen.bounds.width
            let windowHeight: CGFloat = 80

            let window = UIWindow(windowScene: scene)
            window.windowLevel = .toast
            window.backgroundColor = .clear
            window.isUserInteractionEnabled = false   // pass every gesture through
            window.frame = CGRect(x: 0, y: safeAreaTop, width: screenWidth, height: windowHeight)
            window.transform = CGAffineTransform(translationX: 0, y: -(safeAreaTop + windowHeight + 20))
            window.alpha = 0

            let newHost = UIHostingController(rootView: toast.content)
            newHost.view.backgroundColor = .clear
            window.rootViewController = newHost
            window.isHidden = false

            // damping=1 — overdamped, slides in cleanly with no bounce.
            UIView.animate(
                withDuration: 0.4, delay: 0,
                usingSpringWithDamping: 1.0, initialSpringVelocity: 0.6
            ) {
                window.transform = .identity
                window.alpha = 1
            }

            self.window = window
            self.host = newHost
            self.shownID = toast.id
        }

        func hide() {
            guard let w = window else { return }
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
            window = nil
            host = nil
            shownID = nil
        }
    }
}

// MARK: - Previews

#if DEBUG
/// One button per `ToastPresenting.show(...)` call site in the app today —
/// tap to trigger that exact toast through the real `ToastCenter` → `ToastHost`
/// pipeline (see SearchViewModel's reconnect/disconnect toasts, SearchView's
/// copied-to-clipboard and receiving-progress toasts).
private struct ToastHostPreview: View {
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Tap a button to trigger that toast")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Peer reconnected") {
                    ToastCenter.shared.show(id: "reconnectedPeer", duration: 3) {
                        PeerToastCapsule(peer: Peer(displayName: "🦊 Fox"), message: "is connected")
                    }
                }

                Button("Peer disconnected") {
                    ToastCenter.shared.show(id: "disconnectedPeer", duration: 3) {
                        PeerToastCapsule(peer: Peer(displayName: "🐨 Koala"), message: "disconnected")
                    }
                }

                Button("Connections restored") {
                    ToastCenter.shared.show(id: "connectionsRestored", duration: 3) {
                        TextToastCapsule(text: "Connections are restored")
                    }
                }

                Button("Copied to clipboard") {
                    ToastCenter.shared.show { CopiedToast() }
                }

                Button("Receiving progress (persistent, ticks up)") {
                    simulateReceivingProgress()
                }
            }
            .buttonStyle(.bordered)
        }
        .background(ToastHost())
    }

    /// Mirrors how SearchView drives the receiving-progress toast: repeated
    /// `show(id:duration: nil)` calls with the same id update it in place,
    /// then `hide(id:)` dismisses it once the transfer finishes.
    private func simulateReceivingProgress() {
        Task { @MainActor in
            for count in 1...5 {
                ToastCenter.shared.show(id: "receivingProgress", duration: nil) {
                    ReceivingToastCapsule(progress: ReceivingProgress(
                        id: "demo", senderName: "🦔 Hedgehog", receivedCount: count, totalCount: 5
                    ))
                }
                try? await Task.sleep(for: .seconds(0.6))
            }
            ToastCenter.shared.hide(id: "receivingProgress")
        }
    }
}

#Preview("ToastHost — tap to trigger") {
    ToastHostPreview()
}
#endif
