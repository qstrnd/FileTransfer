import SwiftUI
import UIKit

struct PinnedReceivingToast: UIViewRepresentable {
    let progress: ReceivingProgress?

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let progress {
            context.coordinator.show(progress: progress, anchoredTo: uiView)
        } else {
            context.coordinator.hide()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var toastWindow: UIWindow?
        private var host: UIHostingController<ReceivingToastCapsule>?
        private var activeTransferID: String?

        func show(progress: ReceivingProgress, anchoredTo view: UIView) {
            let newView = ReceivingToastCapsule(progress: progress)

            if let host, activeTransferID == progress.id {
                host.rootView = newView
                return
            }

            guard let scene = view.window?.windowScene else { return }

            if toastWindow != nil { hide() }

            let safeAreaTop = view.window?.safeAreaInsets.top ?? 50
            let screenWidth = scene.screen.bounds.width
            let windowHeight: CGFloat = 80

            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert - 1
            window.backgroundColor = .clear
            window.isUserInteractionEnabled = false
            window.frame = CGRect(x: 0, y: safeAreaTop, width: screenWidth, height: windowHeight)
            window.transform = CGAffineTransform(translationX: 0, y: -(safeAreaTop + windowHeight + 20))
            window.alpha = 0

            let newHost = UIHostingController(rootView: newView)
            newHost.view.backgroundColor = .clear
            window.rootViewController = newHost
            window.isHidden = false

            UIView.animate(
                withDuration: 0.4, delay: 0,
                usingSpringWithDamping: 1.0, initialSpringVelocity: 0.6
            ) {
                window.transform = .identity
                window.alpha = 1
            }

            toastWindow = window
            host = newHost
            activeTransferID = progress.id
        }

        func hide() {
            guard let w = toastWindow else { return }
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
            host = nil
            activeTransferID = nil
        }
    }
}

private struct ReceivingToastCapsule: View {
    let progress: ReceivingProgress

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("\(progress.senderName) · \(progress.receivedCount) of \(progress.totalCount)")
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
