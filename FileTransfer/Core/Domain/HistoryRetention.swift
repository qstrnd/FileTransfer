import Foundation

/// How long transferred entries are kept in history before being auto-cleaned.
/// Raw value is the age in days (`0` = keep forever, `-1` = history disabled),
/// so it persists directly.
enum HistoryRetention: Int, CaseIterable, Identifiable, Sendable {
    case disabled = -1
    case week = 7
    case month = 30
    case forever = 0

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .disabled: "Off"
        case .week:     "1 Week"
        case .month:    "1 Month"
        case .forever:  "Forever"
        }
    }

    /// Whether new transfers are recorded to history at all.
    var isRecordingEnabled: Bool { self != .disabled }

    /// Entries created before this date should be removed; `nil` keeps
    /// everything (both `.forever` and `.disabled` leave existing entries alone).
    func cutoff(from now: Date = .now) -> Date? {
        guard rawValue > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: -rawValue, to: now)
    }
}
