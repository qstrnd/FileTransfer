import SwiftUI
import UIKit

/// Single interface for triggering a toast notification from anywhere in the
/// app (view models, use cases, views). A toast is arbitrary SwiftUI content
/// shown in its own always-on-top, gesture-pass-through window — see
/// `ToastHost`, which renders whatever `ToastPresenting` most recently showed.
@MainActor
protocol ToastPresenting: AnyObject {
    func show(id: AnyHashable, duration: TimeInterval?, content: AnyView)
    func hide(id: AnyHashable?)
}

extension ToastPresenting {
    /// Shows `content` for `duration` seconds, then auto-hides. Pass `duration: nil`
    /// for a toast whose lifetime tracks external state (e.g. an in-progress
    /// transfer) rather than a fixed timer — call `hide()` when that state ends.
    ///
    /// A fresh `id` (the default) always replaces whatever toast is currently
    /// showing with a brand-new presentation. Pass an explicit, stable `id` only
    /// when repeated calls should update the same still-showing toast in place
    /// (e.g. a progress capsule ticking up) instead of restarting it.
    func show(id: AnyHashable = UUID(), duration: TimeInterval? = 2, @ViewBuilder content: () -> some View) {
        show(id: id, duration: duration, content: AnyView(content()))
    }

    func hide() { hide(id: nil) }
}

/// Concrete toast store. Owns only the current toast's state and auto-hide
/// timing; `ToastHost` observes `current` and is responsible for actually
/// presenting it in a window.
@Observable
@MainActor
final class ToastCenter: ToastPresenting {
    static let shared = ToastCenter()

    private(set) var current: Toast?
    private var hideTask: Task<Void, Never>?

    struct Toast: Identifiable {
        let id: AnyHashable
        let content: AnyView
    }

    private init() {}

    func show(id: AnyHashable, duration: TimeInterval?, content: AnyView) {
        hideTask?.cancel()
        hideTask = nil
        current = Toast(id: id, content: content)

        guard let duration else { return }
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self, !Task.isCancelled else { return }
            if current?.id == id { current = nil }
        }
    }

    func hide(id: AnyHashable?) {
        if let id, current?.id != id { return }
        hideTask?.cancel()
        hideTask = nil
        current = nil
    }
}

// MARK: - Window level

extension UIWindow.Level {
    /// Above every other window in the app, including modal alerts — a toast
    /// must always be visible regardless of what's currently presented.
    static let toast = UIWindow.Level.alert + 1000
}
