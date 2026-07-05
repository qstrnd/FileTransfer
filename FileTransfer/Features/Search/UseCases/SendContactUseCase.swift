import Contacts
import Observation

@Observable
final class SendContactUseCase {
    private(set) var outgoingTransfer: OutgoingContactTransfer?

    private let session: any NearbySessionService
    private let history: any TransferHistoryGate

    init(session: any NearbySessionService, history: any TransferHistoryGate) {
        self.session = session
        self.history = history
    }

    func send(_ contacts: [CNContact], to peers: [Peer]) {
        guard !contacts.isEmpty, !peers.isEmpty else { return }

        // Downsize any contact photo before it's embedded in the vCard, so a
        // full-resolution Contacts photo doesn't bloat the nearby-session payload.
        let photos = contacts.map(downsizedPhoto)
        let wireContacts = zip(contacts, photos).map { wireContact(for: $0, photo: $1) }
        guard let vCardData = try? CNContactVCardSerialization.data(with: wireContacts) else { return }

        let displayName: String
        if contacts.count == 1 {
            displayName = CNContactFormatter.string(from: contacts[0], style: .fullName) ?? "Contact"
        } else {
            displayName = "\(contacts.count) contacts"
        }

        outgoingTransfer = OutgoingContactTransfer(totalItems: contacts.count, peerCount: peers.count)

        let contactInfos = zip(contacts, photos).map { contact, photo in
            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? "Contact"
            return ContactInfo(name: name, phone: contact.phoneNumbers.first?.value.stringValue, photoData: photo)
        }

        for peer in peers {
            session.sendContact(data: vCardData, to: peer)
        }
        history.add(TransferRecord(
            peers: peers,
            direction: .sent,
            type: .contact,
            detail: displayName,
            contacts: contactInfos
        ))

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            self?.outgoingTransfer?.isComplete = true
            try? await Task.sleep(for: .seconds(1.5))
            self?.outgoingTransfer = nil
        }
    }

    func abort() {
        outgoingTransfer = nil
    }

    // MARK: - Photo

    private func downsizedPhoto(for contact: CNContact) -> Data? {
        guard contact.isKeyAvailable(CNContactImageDataKey),
              let original = contact.imageData else { return nil }
        return ContactPhoto.downsized(original)
    }

    private func wireContact(for contact: CNContact, photo: Data?) -> CNContact {
        guard let photo, let mutable = contact.mutableCopy() as? CNMutableContact else { return contact }
        mutable.imageData = photo
        return mutable
    }
}
