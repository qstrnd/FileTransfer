import Foundation

/// Holds the completion handler iOS passes with
/// `application(_:handleEventsForBackgroundURLSession:completionHandler:)`
/// until the reattached URLSession delivers its queued events and calls
/// `urlSessionDidFinishEvents`. Keyed by session identifier — one handler per
/// background session relaunch.
@MainActor
final class BackgroundSessionCompletionStore {
    static let shared = BackgroundSessionCompletionStore()

    private var handlers: [String: () -> Void] = [:]

    func store(_ handler: @escaping () -> Void, forSession identifier: String) {
        handlers[identifier] = handler
    }

    /// Calls and clears the stored handler, if any. Safe to call when none
    /// is stored (foreground-only session lifetimes).
    func complete(session identifier: String) {
        handlers.removeValue(forKey: identifier)?()
    }
}
