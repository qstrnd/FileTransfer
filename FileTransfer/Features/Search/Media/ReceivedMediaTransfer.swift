import Foundation

struct ReceivedMediaTransfer: Identifiable {
    let id = UUID()
    let senderName: String
    let items: [ReceivedMediaItem]
}
