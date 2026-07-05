import Testing
import Foundation
@testable import FileTransfer

@MainActor
struct TransferItemTests {

    private func peer(_ name: String) -> Peer { Peer(displayName: name, deviceID: UUID()) }

    @Test func asRecord_multiplePeers_roundTrips() {
        let peers = [peer("🐟 Fish"), peer("🦊 Fox")]
        let original = TransferRecord(
            peers: peers, direction: .sent, type: .text, detail: "Hello there!"
        )

        let item = TransferItem(from: original)
        let restored = item.asRecord

        #expect(restored.peers.count == 2)
        #expect(restored.peers == peers, "every recipient must survive the persist/reload round trip")
    }

    @Test func asRecord_singlePeer_roundTrips() {
        let p = peer("🐟 Fish")
        let original = TransferRecord(peers: [p], direction: .sent, type: .text, detail: "Hi")

        let restored = TransferItem(from: original).asRecord

        #expect(restored.peers == [p])
    }

    @Test func asRecord_legacyRowWithoutPeersJSON_fallsBackToSinglePeerFields() {
        // Simulates a row persisted before multi-peer support existed:
        // peersJSON was never populated, only the legacy peerEmoji/peerName columns.
        let p = peer("🐟 Fish")
        let item = TransferItem(from: TransferRecord(
            peers: [p], direction: .received, type: .text, detail: "Hi"
        ))
        item.peersJSON = nil

        let restored = item.asRecord

        #expect(restored.peers == [p], "legacy rows must still resolve to their single original peer")
    }
}
