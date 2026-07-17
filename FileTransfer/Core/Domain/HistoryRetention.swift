import Foundation

/// How long transferred entries are kept in history before being auto-cleaned.
/// Raw value is the age in days (`0` = keep forever), so it persists directly.
enum HistoryRetention: Int, CaseIterable, Identifiable, Sendable {
    case week = 7
    case month = 30
    case forever = 0

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .week:    "1 Week"
        case .month:   "1 Month"
        case .forever: "Forever"
        }
    }

    /// Entries created before this date should be removed; `nil` keeps everything.
    func cutoff(from now: Date = .now) -> Date? {
        guard self != .forever else { return nil }
        return Calendar.current.date(byAdding: .day, value: -rawValue, to: now)
    }
}
