import Foundation
import Observation

/// Owns the user-toggleable settings surfaced in the ⋯ menu — currently just the
/// transfer-history retention. Persists the choice, applies it to the history
/// store, and prunes expired entries when it changes and on launch.
///
/// Extracted from `SearchViewModel` so the menu is a self-contained component
/// with its own state; `SearchViewModel` composes an instance and proxies
/// `isHistoryEnabled` to it.
@Observable
final class SettingsMenuViewModel {
    var historyRetention: HistoryRetention {
        didSet {
            UserDefaults.standard.set(historyRetention.rawValue, forKey: Self.retentionKey)
            historyStore.isRecordingEnabled = historyRetention.isRecordingEnabled
            cleanHistory()
        }
    }

    /// Whether new transfers are recorded to history at all.
    var isHistoryEnabled: Bool { historyRetention.isRecordingEnabled }

    private let historyStore: TransferHistoryStore
    private let attachmentCache: any AttachmentCacheGate

    static let retentionKey = "ft.historyRetentionDays"

    init(historyStore: TransferHistoryStore, attachmentCache: any AttachmentCacheGate) {
        self.historyStore = historyStore
        self.attachmentCache = attachmentCache
        // Setting a property in init doesn't fire didSet, so read the persisted
        // retention here and run the launch-time clean explicitly below. When the
        // user hasn't chosen yet the key is absent (not 0), so default to 1 Month.
        let stored = UserDefaults.standard.object(forKey: Self.retentionKey) as? Int
        historyRetention = stored.flatMap(HistoryRetention.init(rawValue:)) ?? .month
        historyStore.isRecordingEnabled = historyRetention.isRecordingEnabled
        cleanHistory()
    }

    /// Removes history entries — and their cached attachments — older than the
    /// current retention. A no-op while retention is `.forever`. Runs the
    /// filesystem folder sweep off the main actor.
    func cleanHistory() {
        guard let cutoff = historyRetention.cutoff() else { return }
        // Prune every record dated before the cutoff (covers attachment-less
        // entries like text messages), then drop their cached attachments.
        let prunedIDs = historyStore.prune(before: cutoff)
        for id in prunedIDs { attachmentCache.delete(recordID: id) }
        // Filesystem sweep by each transfer folder's creation date — cleans
        // orphaned attachment folders and backs up the record-date prune.
        Task { [weak self] in
            guard let self else { return }
            let removed = await attachmentCache.pruneAttachments(olderThan: cutoff)
            for id in removed { historyStore.delete(id) }
        }
    }
}
