import Foundation

struct OutgoingContactTransfer: Identifiable {
    let id = UUID()
    let totalItems: Int
    let peerCount: Int
    var isComplete: Bool = false
}

