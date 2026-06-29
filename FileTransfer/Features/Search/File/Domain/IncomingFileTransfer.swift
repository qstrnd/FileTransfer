import Foundation

struct IncomingFileTransfer: Identifiable {
    let id: String
    let senderName: String
    let totalCount: Int
    private(set) var received: [Int: ReceivedFile] = [:]

    var receivedCount: Int { received.count }
    var isComplete: Bool { received.count >= totalCount }

    mutating func add(_ file: ReceivedFile, at index: Int) {
        received[index] = file
    }

    var orderedFiles: [ReceivedFile] {
        (0..<totalCount).compactMap { received[$0] }
    }
}
