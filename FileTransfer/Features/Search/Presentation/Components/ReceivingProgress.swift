import Foundation

/// Generic progress snapshot shared by the receiving toast for both media and file transfers.
struct ReceivingProgress: Equatable {
    let id: String
    let senderName: String
    let receivedCount: Int
    let totalCount: Int
}

extension IncomingMediaTransfer {
    var receivingProgress: ReceivingProgress {
        ReceivingProgress(id: id, senderName: senderName, receivedCount: receivedCount, totalCount: totalCount)
    }
}

extension IncomingFileTransfer {
    var receivingProgress: ReceivingProgress {
        ReceivingProgress(id: id, senderName: senderName, receivedCount: receivedCount, totalCount: totalCount)
    }
}
