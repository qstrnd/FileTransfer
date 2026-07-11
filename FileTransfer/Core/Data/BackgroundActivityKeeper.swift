import UIKit

/// Holds a `UIApplication` background task while there's work worth keeping
/// the process alive for (in-flight HTTP receptions after the app leaves the
/// foreground), releasing it after a short grace period once the work drains.
///
/// This buys the standard ~30 s background budget — an honest extension, not
/// a guarantee: iOS may still expire the task, at which point in-flight
/// connections die and the sender's retry/fallback logic takes over.
@MainActor
final class BackgroundActivityKeeper {
    private var taskID: UIBackgroundTaskIdentifier = .invalid
    private var releaseTask: Task<Void, Never>?
    private let gracePeriod: Duration = .seconds(5)

    /// True while any tracked work is active; setting it acquires/schedules
    /// release of the background task.
    var hasActiveWork: Bool = false {
        didSet {
            guard hasActiveWork != oldValue else { return }
            if hasActiveWork { acquire() } else { scheduleRelease() }
        }
    }

    private func acquire() {
        releaseTask?.cancel()
        releaseTask = nil
        guard taskID == .invalid else { return }
        taskID = UIApplication.shared.beginBackgroundTask(withName: "ft.reception") { [weak self] in
            // Expiration: iOS reclaims the budget; end immediately.
            self?.release()
        }
    }

    private func scheduleRelease() {
        releaseTask?.cancel()
        releaseTask = Task { [weak self, gracePeriod] in
            try? await Task.sleep(for: gracePeriod)
            guard !Task.isCancelled else { return }
            self?.release()
        }
    }

    private func release() {
        releaseTask?.cancel()
        releaseTask = nil
        guard taskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(taskID)
        taskID = .invalid
    }
}
