import Foundation

struct ReceivedFileTransfer: Identifiable {
    let id = UUID()
    let senderName: String
    let files: [ReceivedFile]
    /// The history record created for this transfer, so the received alert's
    /// "Keep in Transfer History" toggle can remove it when turned off.
    var recordID: UUID? = nil
}
