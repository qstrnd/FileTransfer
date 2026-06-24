import Testing
import Foundation
@testable import FileTransfer

@MainActor
struct DeviceIdentityTests {

    @Test func generatesPersistentUUID() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let store = UserDefaultsDeviceIdentityStore(defaults: defaults)
        let id = store.deviceID
        #expect(id != UUID()) // is a real UUID (not default)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func uuidIsStableAcrossMultipleCalls() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let store = UserDefaultsDeviceIdentityStore(defaults: defaults)
        let first  = store.deviceID
        let second = store.deviceID
        #expect(first == second)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func uuidIsStableAcrossNewStoreInstances() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let id1 = UserDefaultsDeviceIdentityStore(defaults: defaults).deviceID
        let id2 = UserDefaultsDeviceIdentityStore(defaults: defaults).deviceID
        #expect(id1 == id2)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func differentSuitesProduceDifferentUUIDs() {
        let d1 = UserDefaults(suiteName: UUID().uuidString)!
        let d2 = UserDefaults(suiteName: UUID().uuidString)!
        let id1 = UserDefaultsDeviceIdentityStore(defaults: d1).deviceID
        let id2 = UserDefaultsDeviceIdentityStore(defaults: d2).deviceID
        // Two fresh installations should each get a unique UUID.
        #expect(id1 != id2)
    }
}
