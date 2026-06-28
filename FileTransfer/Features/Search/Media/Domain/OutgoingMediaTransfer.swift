import Foundation

struct OutgoingMediaTransfer: Identifiable {
    let id = UUID()
    let totalItems: Int
    let peerCount: Int
    private(set) var completions: Int = 0

    var totalCompletions: Int { totalItems * peerCount }
    var isComplete: Bool { totalItems == 0 || completions >= totalCompletions }

    mutating func recordCompletion() {
        completions = min(completions + 1, totalCompletions)
    }
}

