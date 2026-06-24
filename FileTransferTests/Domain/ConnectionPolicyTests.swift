import Testing
import Foundation
@testable import FileTransfer

@MainActor
struct ConnectionPolicyTests {

    // MARK: - canInitiate

    @Test func canInitiate_fromIdle() {
        #expect(ConnectionPolicy.canInitiate(from: .idle) == true)
    }

    @Test func canInitiate_fromRejected() {
        // Rule 2: a declined peer must remain connectable.
        #expect(ConnectionPolicy.canInitiate(from: .rejected) == true)
    }

    @Test func cannotInitiate_fromConnecting() {
        #expect(ConnectionPolicy.canInitiate(from: .connecting) == false)
    }

    @Test func cannotInitiate_fromConnected() {
        #expect(ConnectionPolicy.canInitiate(from: .connected) == false)
    }

    // MARK: - qualifiesForAutoReconnect

    @Test func autoReconnect_returnsFalse_whenNoPeerDeviceID() {
        let peer = Peer(displayName: "🐟 Fish", deviceID: nil)
        let history = InMemoryConnectionHistoryStore()
        #expect(ConnectionPolicy.qualifiesForAutoReconnect(to: peer, history: history) == false)
    }

    @Test func autoReconnect_returnsFalse_whenNotInHistory() {
        let peer = Peer(displayName: "🐟 Fish", deviceID: UUID())
        let history = InMemoryConnectionHistoryStore()
        #expect(ConnectionPolicy.qualifiesForAutoReconnect(to: peer, history: history) == false)
    }

    @Test func autoReconnect_returnsTrue_whenInHistory() {
        let id = UUID()
        let peer = Peer(displayName: "🐟 Fish", deviceID: id)
        let history = InMemoryConnectionHistoryStore()
        history.record(ConnectionRecord(deviceID: id, displayName: peer.displayName, lastConnected: .now))
        #expect(ConnectionPolicy.qualifiesForAutoReconnect(to: peer, history: history) == true)
    }
}

// InMemoryConnectionHistoryStore lives in Core/Data/ and is available via @testable import.
