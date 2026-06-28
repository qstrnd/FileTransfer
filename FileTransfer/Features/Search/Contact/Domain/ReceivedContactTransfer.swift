import Foundation

struct ReceivedContactTransfer: Identifiable {
    let id = UUID()
    let senderName: String
    let contacts: [ContactItem]
    /// Raw vCard payload used when saving to the system address book.
    let vCardData: Data
}
