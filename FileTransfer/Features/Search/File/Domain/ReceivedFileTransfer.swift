import Foundation

struct ReceivedFileTransfer: Identifiable {
    let id = UUID()
    let senderName: String
    let files: [ReceivedFile]
}
