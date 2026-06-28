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
        guard let vCardData = try? CNContactVCardSerialization.data(with: contacts) else { return }

        let displayName: String
        if contacts.count == 1 {
            displayName = CNContactFormatter.string(from: contacts[0], style: .fullName) ?? "Contact"
        } else {
            displayName = "\(contacts.count) contacts"
        }

        outgoingTransfer = OutgoingContactTransfer(totalItems: contacts.count, peerCount: peers.count)

        for peer in peers {
            session.sendContact(data: vCardData, to: peer)
            history.add(TransferRecord(
                peerEmoji: peer.emojiComponent,
                peerName: peer.nameComponent,
                direction: .sent,
                type: .contact,
                detail: displayName
            ))
        }

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
}
