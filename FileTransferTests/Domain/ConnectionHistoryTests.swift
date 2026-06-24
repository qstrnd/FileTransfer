import Testing
import Foundation
@testable import FileTransfer

@MainActor
struct ConnectionHistoryTests {

    // Isolated UserDefaults suite per test to avoid cross-test contamination.
    private func makeStore() -> (UserDefaultsConnectionHistoryStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        return (UserDefaultsConnectionHistoryStore(defaults: defaults), defaults)
    }

    @Test func startsEmpty() {
        let (store, _) = makeStore()
        #expect(store.allRecords().isEmpty)
    }

    @Test func recordsConnection() {
        let (store, _) = makeStore()
        let id = UUID()
        store.record(ConnectionRecord(deviceID: id, displayName: "🦁 Lion", lastConnected: .now))
        #expect(store.allRecords().count == 1)
        #expect(store.allRecords().first?.deviceID == id)
    }

    @Test func hasConnected_returnsTrueAfterRecord() {
        let (store, _) = makeStore()
        let id = UUID()
        store.record(ConnectionRecord(deviceID: id, displayName: "🐟 Fish", lastConnected: .now))
        #expect(store.hasConnected(to: id) == true)
    }

    @Test func hasConnected_returnsFalseForUnknownDevice() {
        let (store, _) = makeStore()
        #expect(store.hasConnected(to: UUID()) == false)
    }

    @Test func deduplicates_sameDeviceID() {
        let (store, _) = makeStore()
        let id = UUID()
        let t1 = Date(timeIntervalSinceNow: -60)
        let t2 = Date.now
        store.record(ConnectionRecord(deviceID: id, displayName: "Old Name", lastConnected: t1))
        store.record(ConnectionRecord(deviceID: id, displayName: "New Name", lastConnected: t2))
        #expect(store.allRecords().count == 1)
        #expect(store.allRecords().first?.displayName == "New Name")
        #expect(store.allRecords().first?.lastConnected == t2)
    }

    @Test func persistsAcrossStoreInstances() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let id = UUID()
        UserDefaultsConnectionHistoryStore(defaults: defaults)
            .record(ConnectionRecord(deviceID: id, displayName: "🦊 Fox", lastConnected: .now))
        let fresh = UserDefaultsConnectionHistoryStore(defaults: defaults)
        #expect(fresh.hasConnected(to: id) == true)
    }

    @Test func recordPeer_convenience_storesDeviceID() {
        let (store, _) = makeStore()
        let id = UUID()
        let peer = Peer(displayName: "🐺 Wolf", deviceID: id)
        store.record(peer: peer)
        #expect(store.hasConnected(to: id) == true)
    }

    @Test func recordPeer_ignoresPeerWithoutDeviceID() {
        let (store, _) = makeStore()
        let peer = Peer(displayName: "🐺 Wolf", deviceID: nil)
        store.record(peer: peer)
        #expect(store.allRecords().isEmpty)
    }
}
