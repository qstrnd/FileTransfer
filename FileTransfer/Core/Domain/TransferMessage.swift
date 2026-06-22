import Foundation

struct TransferMessage: Sendable, Identifiable, Equatable {
    let id: UUID
    let senderName: String
    let text: String

    nonisolated init(senderName: String, text: String) {
        self.id = UUID()
        self.senderName = senderName
        self.text = text
    }
}
