import Testing
import Foundation
import MultipeerConnectivity
@testable import FileTransfer

/// Tests for PeerRegistry — the discovery map that owns the MCPeerID lifetime.
///
/// The central invariant: entries survive session disconnects and are only
/// removed by browser events (`peerLost`) or full teardown (`reset`).
/// This invariant prevents the reconnect regression where a session
/// `.notConnected` callback wiped the entry and made re-invitation impossible.
@MainActor
struct PeerRegistryTests {

    private func id(_ name: String) -> MCPeerID { MCPeerID(displayName: name) }
    private let uuid = UUID()

    // MARK: - peerFound

    @Test func peerFound_makesLookupAvailable() {
        var reg = PeerRegistry()
        let peerID = id("🐟 Fish")
        reg.peerFound(peerID, deviceID: uuid)
        #expect(reg.mcPeerID(for: peerID.displayName) == peerID)
        #expect(reg.deviceID(for: peerID.displayName) == uuid)
    }

    @Test func peerFound_nilDeviceID_storesNil() {
        var reg = PeerRegistry()
        let peerID = id("🦁 Lion")
        reg.peerFound(peerID, deviceID: nil)
        #expect(reg.mcPeerID(for: peerID.displayName) == peerID)
        #expect(reg.deviceID(for: peerID.displayName) == nil)
    }

    @Test func peerFound_overwritesExistingEntry() {
        var reg = PeerRegistry()
        let first  = MCPeerID(displayName: "🐺 Wolf")
        let second = MCPeerID(displayName: "🐺 Wolf")
        let id1 = UUID(), id2 = UUID()
        reg.peerFound(first,  deviceID: id1)
        reg.peerFound(second, deviceID: id2)
        #expect(reg.mcPeerID(for: "🐺 Wolf") == second)
        #expect(reg.deviceID(for: "🐺 Wolf") == id2)
    }

    @Test func peerFound_multiplePeers() {
        var reg = PeerRegistry()
        reg.peerFound(id("A"), deviceID: nil)
        reg.peerFound(id("B"), deviceID: nil)
        #expect(reg.count == 2)
    }

    // MARK: - peerLost

    @Test func peerLost_removesEntry() {
        var reg = PeerRegistry()
        let peerID = id("🦊 Fox")
        reg.peerFound(peerID, deviceID: uuid)
        reg.peerLost(displayName: peerID.displayName)
        #expect(reg.mcPeerID(for: peerID.displayName) == nil)
        #expect(reg.deviceID(for: peerID.displayName) == nil)
    }

    @Test func peerLost_unknownName_isNoop() {
        var reg = PeerRegistry()
        reg.peerLost(displayName: "nobody")
        #expect(reg.isEmpty)
    }

    @Test func peerLost_onlyRemovesTargetPeer() {
        var reg = PeerRegistry()
        reg.peerFound(id("A"), deviceID: nil)
        reg.peerFound(id("B"), deviceID: nil)
        reg.peerLost(displayName: "A")
        #expect(reg.mcPeerID(for: "A") == nil)
        #expect(reg.mcPeerID(for: "B") != nil)
        #expect(reg.count == 1)
    }

    // MARK: - reset

    @Test func reset_clearsEverything() {
        var reg = PeerRegistry()
        reg.peerFound(id("A"), deviceID: UUID())
        reg.peerFound(id("B"), deviceID: UUID())
        reg.reset()
        #expect(reg.isEmpty)
        #expect(reg.count == 0)
    }

    // MARK: - Reconnect regression

    /// Core regression test for the "can't reconnect after disconnect" bug.
    ///
    /// Old behaviour: `MCSessionDelegate.session(_:peer:didChange:.notConnected)`
    /// called `peerIDMap.removeValue`, wiping the MCPeerID on every disconnect.
    /// Subsequent `connect(to:)` calls silently returned early because the lookup
    /// returned nil — permanent broken state until app restart.
    ///
    /// Fixed by giving the registry its own type with no session-state mutators.
    /// The absence of a `sessionDisconnected(_:)` method IS the invariant this
    /// test documents: the entry must survive disconnect so reconnect can
    /// immediately send a fresh invitation on the still-valid session.
    @Test func peerRemainsAvailableAfterSessionDisconnect() {
        var reg = PeerRegistry()
        let peerID = id("🐟 Fantastic Fish")

        // 1. Browser discovers peer.
        reg.peerFound(peerID, deviceID: uuid)
        #expect(reg.mcPeerID(for: peerID.displayName) != nil)

        // 2. Session disconnects.
        //    PeerRegistry has no mutation method for this event — intentionally.
        //    The compiler enforces it: there is nothing to call here.

        // 3. Entry survives; reconnect can re-invite without rediscovery.
        #expect(
            reg.mcPeerID(for: peerID.displayName) != nil,
            "MCPeerID must survive session disconnect so reconnection works"
        )
        #expect(reg.mcPeerID(for: peerID.displayName) == peerID)
    }

    @Test func fullReconnectCycle_registryState() {
        var reg = PeerRegistry()
        let peerID = id("🦋 Butterfly")

        // Discover
        reg.peerFound(peerID, deviceID: uuid)
        #expect(reg.mcPeerID(for: peerID.displayName) != nil)

        // Connect (no registry change)
        // Session disconnect (no registry change)
        // Re-invite possible immediately:
        #expect(reg.mcPeerID(for: peerID.displayName) != nil, "entry persists through connect+disconnect")

        // Connect again (no registry change)
        // Peer physically leaves — only then remove:
        reg.peerLost(displayName: peerID.displayName)
        #expect(reg.mcPeerID(for: peerID.displayName) == nil)
    }

    // MARK: - peer(for:)

    @Test func peer_returnsCorrectEntity() {
        var reg = PeerRegistry()
        let peerID = id("🌟 Star")
        reg.peerFound(peerID, deviceID: uuid)
        let peer = reg.peer(for: peerID)
        #expect(peer.displayName == peerID.displayName)
        #expect(peer.deviceID == uuid)
    }

    @Test func peer_unknownPeer_returnsEntityWithNilDeviceID() {
        let reg = PeerRegistry()
        let peerID = id("Unknown")
        let peer = reg.peer(for: peerID)
        #expect(peer.displayName == peerID.displayName)
        #expect(peer.deviceID == nil)
    }
}

// MARK: - Reconnect state machine regression

/// Verifies the ViewModel state machine allows reconnection after both
/// types of disconnect, complementing PeerRegistryTests at the domain layer.
@MainActor
struct ReconnectStateTests {

    @Test func canReconnect_afterPeerInitiatedDisconnect() {
        // Rule 4: after peerDisconnected the state is idle → can reconnect
        var state = PeerConnectionState.connected
        state = state.applying(.peerDisconnected)!
        #expect(state == .idle)
        #expect(ConnectionPolicy.canInitiate(from: state))
        #expect(state.applying(.initiateConnection) == .connecting)
    }

    @Test func canReconnect_afterLocalDisconnect() {
        // Rule 4: after initiateDisconnection the state is idle → can reconnect
        var state = PeerConnectionState.connected
        state = state.applying(.initiateDisconnection)!
        #expect(state == .idle)
        #expect(ConnectionPolicy.canInitiate(from: state))
        #expect(state.applying(.initiateConnection) == .connecting)
    }

    @Test func multipleReconnectCycles() {
        var state = PeerConnectionState.idle
        for _ in 1...3 {
            state = state.applying(.initiateConnection)!
            #expect(state == .connecting)
            state = state.applying(.connectionAccepted)!
            #expect(state == .connected)
            state = state.applying(.peerDisconnected)!
            #expect(state == .idle)
        }
    }
}
