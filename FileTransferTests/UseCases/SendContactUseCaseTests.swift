import Testing
import Foundation
import Contacts
@testable import FileTransfer

// MARK: - Spies

@MainActor
private final class SpyNearbySessionService: NearbySessionService {
    var delegate: (any NearbySessionServiceDelegate)?
    private(set) var sendContactCalls: [(data: Data, peer: Peer)] = []

    func start(displayName: String, deviceID: UUID) {}
    func stop() {}
    func connect(to peer: Peer, isReconnect: Bool) {}
    func disconnect(from peer: Peer) {}
    func send(text: String, to peer: Peer) {}
    @discardableResult
    func sendMedia(_ files: [MediaFileToSend], to peer: Peer, onItemSent: @escaping @MainActor () -> Void) -> [Progress] { [] }
    @discardableResult
    func sendFiles(_ files: [FileToSend], to peer: Peer, onItemSent: @escaping @MainActor () -> Void) -> [Progress] { [] }
    func sendContact(data: Data, to peer: Peer) { sendContactCalls.append((data, peer)) }
    func sendPing(to peer: Peer) {}
    func sendPong(to peer: Peer) {}
    func acceptInvitation() {}
    func declineInvitation() {}
}

private final class SpyHistoryGate: TransferHistoryGate, @unchecked Sendable {
    private(set) var addedRecords: [TransferRecord] = []
    func add(_ record: TransferRecord) { addedRecords.append(record) }
}

// MARK: - Tests

@MainActor
struct SendContactUseCaseTests {

    private func peer(_ name: String) -> Peer { Peer(displayName: name, deviceID: UUID()) }

    private func makeContact(_ name: String) -> CNContact {
        let contact = CNMutableContact()
        contact.givenName = name
        return contact
    }

    private func makeUseCase() -> (SendContactUseCase, SpyNearbySessionService, SpyHistoryGate) {
        let service = SpyNearbySessionService()
        let history = SpyHistoryGate()
        let useCase = SendContactUseCase(session: service, history: history)
        return (useCase, service, history)
    }

    @Test func send_multiplePeers_createsSingleRecordWithAllPeers() {
        let (useCase, service, history) = makeUseCase()
        let peers = [peer("🐟 Fish"), peer("🦊 Fox")]

        useCase.send([makeContact("Jane Doe")], to: peers)

        #expect(history.addedRecords.count == 1, "one send to multiple peers must produce a single history entry")
        #expect(history.addedRecords.first?.peers.count == 2)
        #expect(service.sendContactCalls.count == 2, "the vCard must still be sent to every peer individually")
    }

    @Test func send_singlePeer_createsRecordWithThatPeer() {
        let (useCase, _, history) = makeUseCase()
        let p = peer("🐟 Fish")

        useCase.send([makeContact("Jane Doe")], to: [p])

        #expect(history.addedRecords.count == 1)
        #expect(history.addedRecords.first?.peers == [p])
    }

    @Test func send_noPeers_addsNoRecord() {
        let (useCase, _, history) = makeUseCase()

        useCase.send([makeContact("Jane Doe")], to: [])

        #expect(history.addedRecords.isEmpty)
    }

    @Test func send_noContacts_addsNoRecord() {
        let (useCase, _, history) = makeUseCase()

        useCase.send([], to: [peer("🐟 Fish")])

        #expect(history.addedRecords.isEmpty)
    }
}
