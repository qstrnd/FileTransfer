import Foundation

struct IncomingMediaTransfer: Identifiable {
    let id: String
    let senderName: String
    let totalCount: Int
    private(set) var received: [Int: URL] = [:]

    var receivedCount: Int { received.count }
    var isComplete: Bool { received.count >= totalCount }
    var orderedURLs: [URL] { (0..<totalCount).compactMap { received[$0] } }

    mutating func add(url: URL, at index: Int) { received[index] = url }
}
