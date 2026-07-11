import Foundation

struct OutgoingMediaTransfer: Identifiable {
    let id = UUID()
    let totalItems: Int
    let peerCount: Int
    private(set) var completions: Int = 0
    private(set) var failures: Int = 0
    var progress: Double = 0

    var totalCompletions: Int { totalItems * peerCount }
    /// Failures are terminal outcomes too — a batch with failed items still ends.
    var isComplete: Bool { totalItems == 0 || completions + failures >= totalCompletions }
    var hasFailed: Bool { failures > 0 }

    mutating func recordCompletion() {
        completions = min(completions + 1, totalCompletions)
    }

    mutating func recordFailure() {
        failures = min(failures + 1, totalCompletions)
    }
}

