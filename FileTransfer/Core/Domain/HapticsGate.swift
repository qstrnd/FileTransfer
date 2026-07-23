import Foundation

/// Centralized interface for haptic feedback, so call sites express intent
/// (a tap, a positive outcome, a soft warning, a hard failure) instead of
/// picking a raw UIKit generator style directly at every call site.
@MainActor
protocol HapticsGate: AnyObject {
    /// A light tap — share/connect/accept/decline button presses.
    func light()
    /// A strong, attention-grabbing cue — connection errors, failed sends.
    func heavy()
    /// A positive outcome — a peer connected, a message/file/contact arrived.
    func success()
    /// A soft warning — "nothing to share", "select a device first".
    func warning()
}
