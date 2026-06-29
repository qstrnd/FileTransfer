import Foundation

struct OutgoingFileTransfer: Identifiable {
    let id = UUID()
    let totalFiles: Int
    let peerCount: Int
    private(set) var completions: Int = 0

    var totalCompletions: Int { totalFiles * peerCount }
    var isComplete: Bool { totalFiles == 0 || completions >= totalCompletions }

    mutating func recordCompletion() {
        completions = min(completions + 1, totalCompletions)
    }
}
