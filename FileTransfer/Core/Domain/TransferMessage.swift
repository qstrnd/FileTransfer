import Foundation

struct TransferMessage: Identifiable, Equatable {
    let id: UUID
    let senderName: String
    let text: String

    init(senderName: String, text: String) {
        self.id = UUID()
        self.senderName = senderName
        self.text = text
    }
}
