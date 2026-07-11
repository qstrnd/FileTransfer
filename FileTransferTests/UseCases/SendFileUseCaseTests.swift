import Testing
import Foundation
@testable import FileTransfer

// MARK: - Spies

@MainActor
private final class SpyNearbySessionService: NearbySessionService {
    var delegate: (any NearbySessionServiceDelegate)?
    private(set) var sendFilesCalls: [(files: [FileToSend], peer: Peer)] = []

    func start(displayName: String, deviceID: UUID) {}
    func stop() {}
    func connect(to peer: Peer, isReconnect: Bool) {}
    func disconnect(from peer: Peer) {}
    func send(text: String, to peer: Peer) {}
    @discardableResult
    func sendMedia(_ files: [MediaFileToSend], to peer: Peer, onItemCompleted: @escaping @MainActor (Result<Void, TransferSendError>) -> Void) -> [Progress] { [] }
    @discardableResult
    func sendFiles(_ files: [FileToSend], to peer: Peer, onItemCompleted: @escaping @MainActor (Result<Void, TransferSendError>) -> Void) -> [Progress] {
        sendFilesCalls.append((files, peer))
        return []
    }
    func sendContact(data: Data, to peer: Peer) {}
    func sendPing(to peer: Peer) {}
    func sendPong(to peer: Peer) {}
    func acceptInvitation() {}
    func declineInvitation() {}
}

private final class SpyHistoryGate: TransferHistoryGate, @unchecked Sendable {
    private(set) var addedRecords: [TransferRecord] = []
    func add(_ record: TransferRecord) { addedRecords.append(record) }
}

private final class SpyAttachmentCache: AttachmentCacheGate, @unchecked Sendable {
    private(set) var cacheCallCount = 0
    func cache(_ urls: [URL], names: [String?], forRecord id: UUID) async -> [URL] {
        cacheCallCount += 1
        return urls
    }
    func fileBytes(for urls: [URL]) -> Int64 { 0 }
    func delete(recordID id: UUID) {}
}

// MARK: - Tests

@MainActor
struct SendFileUseCaseTests {

    private func peer(_ name: String) -> Peer { Peer(displayName: name, deviceID: UUID()) }

    private func makeUseCase() -> (SendFileUseCase, SpyNearbySessionService, SpyHistoryGate, SpyAttachmentCache) {
        let service = SpyNearbySessionService()
        let history = SpyHistoryGate()
        let cache = SpyAttachmentCache()
        let useCase = SendFileUseCase(session: service, history: history, attachmentCache: cache)
        return (useCase, service, history, cache)
    }

    @Test func send_multiplePeers_createsSingleRecordWithAllPeers() async throws {
        let (useCase, service, history, cache) = makeUseCase()
        let peers = [peer("🐟 Fish"), peer("🦊 Fox")]

        useCase.send([URL(fileURLWithPath: "/tmp/report.pdf")], to: peers)
        try await Task.sleep(for: .milliseconds(50))

        #expect(history.addedRecords.count == 1, "one send to multiple peers must produce a single history entry")
        #expect(history.addedRecords.first?.peers.count == 2)
        #expect(service.sendFilesCalls.count == 2, "the file must still be sent to every peer individually")
        #expect(cache.cacheCallCount == 1, "attachments are cached once, not once per peer")
    }

    @Test func send_singlePeer_createsRecordWithThatPeer() async throws {
        let (useCase, _, history, _) = makeUseCase()
        let p = peer("🐟 Fish")

        useCase.send([URL(fileURLWithPath: "/tmp/report.pdf")], to: [p])
        try await Task.sleep(for: .milliseconds(50))

        #expect(history.addedRecords.count == 1)
        #expect(history.addedRecords.first?.peers == [p])
    }

    @Test func send_noPeers_addsNoRecord() async throws {
        let (useCase, _, history, _) = makeUseCase()

        useCase.send([URL(fileURLWithPath: "/tmp/report.pdf")], to: [])
        try await Task.sleep(for: .milliseconds(50))

        #expect(history.addedRecords.isEmpty)
    }

    @Test func send_noFiles_addsNoRecord() async throws {
        let (useCase, _, history, _) = makeUseCase()

        useCase.send([], to: [peer("🐟 Fish")])
        try await Task.sleep(for: .milliseconds(50))

        #expect(history.addedRecords.isEmpty)
    }
}
