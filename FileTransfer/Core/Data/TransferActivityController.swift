#if !targetEnvironment(macCatalyst)
// @preconcurrency: ActivityKit's Activity class carries no Sendable
// annotation even though its async update/end are documented for use from
// any context (internally synchronized). Without this, strict concurrency
// rejects every update/end call as an illegal send of a non-Sendable value.
@preconcurrency import ActivityKit
#endif
import Foundation
import OSLog

/// ActivityKit implementation of `TransferActivityGate`: one Live Activity
/// per in-flight batch, updates throttled (≥5% progress delta or ≥1s apart;
/// terminal states always delivered), ended with a short dwell so the final
/// success/failure state is readable before dismissal.
///
/// No-ops gracefully when Live Activities are disabled. Activities carry a
/// stale date so that if the app is suspended (or killed) mid-batch and the
/// final update never arrives, the system dims the activity instead of
/// showing frozen progress as if it were live.
///
/// `Activity` is not Sendable, so entries hold only the activity's id and a
/// fresh reference is fetched from `Activity.activities` inside each update
/// task — the non-Sendable value never crosses an isolation region.
///
/// Live Activities don't exist on macOS, so under Mac Catalyst every method
/// is a no-op.
@MainActor
final class TransferActivityController: TransferActivityGate {
    nonisolated private static let log = Logger(subsystem: "com.qstrnd.FileTransfer", category: "LiveActivity")

    #if !targetEnvironment(macCatalyst)
    private struct Entry {
        let activityID: String
        let direction: TransferActivityDirection
        let totalItems: Int
        var lastProgress: Double = 0
        var lastUpdate: Date = .distantPast
    }

    private var entries: [String: Entry] = [:]
    private static let staleAfter: TimeInterval = 60
    #endif

    // MARK: - TransferActivityGate

    func startActivity(key: String, peerName: String, direction: TransferActivityDirection, totalItems: Int) {
        #if !targetEnvironment(macCatalyst)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Self.log.info("live activities disabled — skipping")
            return
        }
        guard entries[key] == nil else { return }

        let attributes = TransferActivityAttributes(
            peerName: peerName,
            direction: direction == .send ? .send : .receive,
            totalItems: totalItems,
            transferKey: key
        )
        let state = TransferActivityAttributes.ContentState(
            progress: 0, completedItems: 0,
            phase: direction == .send ? .sending : .receiving
        )
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: .now + Self.staleAfter)
            )
            entries[key] = Entry(activityID: activity.id, direction: direction, totalItems: totalItems)
            Self.log.info("activity started for \(key, privacy: .public)")
        } catch {
            // Foreground-only API; a batch starting while backgrounded lands here.
            Self.log.warning("activity request failed: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    func updateActivity(key: String, progress: Double, completedItems: Int) {
        #if !targetEnvironment(macCatalyst)
        guard var entry = entries[key] else { return }
        let now = Date.now
        guard progress - entry.lastProgress >= 0.05 || now.timeIntervalSince(entry.lastUpdate) >= 1 else { return }
        entry.lastProgress = progress
        entry.lastUpdate = now
        entries[key] = entry

        let state = TransferActivityAttributes.ContentState(
            progress: min(1, max(0, progress)),
            completedItems: completedItems,
            phase: entry.direction == .send ? .sending : .receiving
        )
        deliver(to: entry.activityID) { activity in
            await activity.update(.init(state: state, staleDate: .now + Self.staleAfter))
        }
        #endif
    }

    func endActivity(key: String, outcome: TransferActivityOutcome) {
        #if !targetEnvironment(macCatalyst)
        guard let entry = entries.removeValue(forKey: key) else { return }
        let state = TransferActivityAttributes.ContentState(
            progress: outcome == .success ? 1 : entry.lastProgress,
            completedItems: outcome == .success ? entry.totalItems : 0,
            phase: outcome == .success ? .success : .failure
        )
        let dwell: TimeInterval = outcome == .success ? 4 : 8
        Self.log.info("activity ended for \(key, privacy: .public): \(outcome == .success ? "success" : "failure", privacy: .public)")
        deliver(to: entry.activityID) { activity in
            await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .after(.now + dwell))
        }
        #endif
    }

    // MARK: - Private

    #if !targetEnvironment(macCatalyst)
    /// Fetches the activity by id and applies `operation` in a detached task.
    nonisolated private func deliver(
        to activityID: String,
        operation: @escaping @Sendable (Activity<TransferActivityAttributes>) async -> Void
    ) {
        Task.detached {
            guard let activity = Activity<TransferActivityAttributes>.activities
                .first(where: { $0.id == activityID }) else { return }
            await operation(activity)
        }
    }
    #endif
}
