import Foundation

struct ReceivedContactTransfer: Identifiable {
    let id = UUID()
    let senderName: String
    let contacts: [ContactItem]
    /// Raw vCard payload used when saving to the system address book.
    let vCardData: Data
    /// The history record created for this transfer, so the received alert's
    /// "Keep in Transfer History" toggle can remove it when turned off.
    var recordID: UUID? = nil
}
