import SwiftUI
import UIKit

/// Generic UIWindow host for SwiftUI alert/overlay views that must appear above
/// sheets and full-screen covers.
///
/// The hosted `Content` is responsible for its own show/hide animation (optional
/// binding, spring transition, etc.). `PinnedWindow` only manages the UIWindow
/// lifetime: it creates the window when `isVisible` first becomes true, keeps it
/// alive while `isVisible` is false so the content's exit animation can play, then
/// hides it after `hideDelay` seconds.
///
/// Usage in SearchView:
/// ```swift
/// .background(
///     PinnedWindow(
///         content: InvitationAlert(peer: viewModel.pendingInvitationFrom,
///                                  onAccept: viewModel.acceptInvitation,
///                                  onDecline: viewModel.declineInvitation),
///         isVisible: viewModel.pendingInvitationFrom != nil,
///         isInteractive: true,
///         hideDelay: 0.45
///     )
/// )
/// ```
struct PinnedWindow<Content: View>: UIViewRepresentable {
    let content: Content
    /// When true, create and show the window; when false, schedule a hide.
    let isVisible: Bool
    var windowLevel: UIWindow.Level = .alert - 1
    var isInteractive: Bool = true
    /// Seconds to wait before hiding the UIWindow after `isVisible` → false.
    /// Set to the longest exit animation duration of the hosted `Content`.
    var hideDelay: TimeInterval = 0

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.update(content: content, isVisible: isVisible, anchoredTo: uiView)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    // MARK: - Coordinator

    final class Coordinator {
        private let parent: PinnedWindow<Content>
        private var window: UIWindow?
        private var host: UIHostingController<Content>?
        private var pendingHide: DispatchWorkItem?

        init(parent: PinnedWindow<Content>) { self.parent = parent }

        func update(content: Content, isVisible: Bool, anchoredTo view: UIView) {
            if let host {
                // Window already exists — just update the hosted view.
                host.rootView = content

                if isVisible {
                    pendingHide?.cancel()
                    pendingHide = nil
                    window?.isUserInteractionEnabled = parent.isInteractive
                    window?.isHidden = false
                    UIView.animate(withDuration: 0.2) { self.window?.alpha = 1 }
                } else {
                    window?.isUserInteractionEnabled = false
                    scheduleHide()
                }
                return
            }

            guard isVisible, let scene = view.window?.windowScene else { return }

            let newHost = UIHostingController(rootView: content)
            newHost.view.backgroundColor = .clear

            let newWindow = UIWindow(windowScene: scene)
            newWindow.windowLevel = parent.windowLevel
            newWindow.backgroundColor = .clear
            newWindow.rootViewController = newHost
            newWindow.isUserInteractionEnabled = parent.isInteractive
            newWindow.alpha = 0
            newWindow.isHidden = false

            UIView.animate(
                withDuration: 0.35, delay: 0,
                usingSpringWithDamping: 0.85, initialSpringVelocity: 0
            ) { newWindow.alpha = 1 }

            self.window = newWindow
            self.host = newHost
        }

        private func scheduleHide() {
            pendingHide?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self, let w = self.window else { return }
                UIView.animate(withDuration: 0.3) { w.alpha = 0 } completion: { _ in
                    w.isHidden = true
                }
                self.window = nil
                self.host = nil
            }
            pendingHide = item
            DispatchQueue.main.asyncAfter(deadline: .now() + parent.hideDelay, execute: item)
        }
    }
}
