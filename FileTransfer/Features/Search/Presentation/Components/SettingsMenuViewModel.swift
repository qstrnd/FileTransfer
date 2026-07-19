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
            defaults.set(historyRetention.rawValue, forKey: Self.retentionKey)
            historyStore.isRecordingEnabled = historyRetention.isRecordingEnabled
            cleanHistory()
        }
    }

    /// Whether new transfers are recorded to history at all.
    var isHistoryEnabled: Bool { historyRetention.isRecordingEnabled }

    /// When on (the default), the app automatically (re)connects to previously
    /// connected devices as they're discovered. When off, all connections are
    /// initiated manually — nothing auto-connects and incoming reconnect
    /// invitations fall back to the manual accept/decline alert.
    var autoConnectOnStartup: Bool {
        didSet { defaults.set(autoConnectOnStartup, forKey: Self.autoConnectKey) }
    }

    private let historyStore: TransferHistoryStore
    private let attachmentCache: any AttachmentCacheGate
    private let defaults: UserDefaults

    static let retentionKey = "ft.historyRetentionDays"
    static let autoConnectKey = "ft.autoConnectOnStartup"

    init(
        historyStore: TransferHistoryStore,
        attachmentCache: any AttachmentCacheGate,
        defaults: UserDefaults = .standard
    ) {
        self.historyStore = historyStore
        self.attachmentCache = attachmentCache
        self.defaults = defaults
        // Setting a property in init doesn't fire didSet, so read the persisted
        // retention here and run the launch-time clean explicitly below. When the
        // user hasn't chosen yet the key is absent (not 0), so default to 1 Month.
        let stored = defaults.object(forKey: Self.retentionKey) as? Int
        historyRetention = stored.flatMap(HistoryRetention.init(rawValue:)) ?? .month
        // Absent key → on by default.
        autoConnectOnStartup = defaults.object(forKey: Self.autoConnectKey) as? Bool ?? true
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
