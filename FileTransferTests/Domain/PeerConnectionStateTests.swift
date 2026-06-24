import Testing
@testable import FileTransfer

@MainActor
struct PeerConnectionStateTests {

    // MARK: - Valid transitions

    @Test func idle_initiateConnection_yieldsConnecting() {
        #expect(PeerConnectionState.idle.applying(.initiateConnection) == .connecting)
    }

    @Test func rejected_initiateConnection_yieldsConnecting() {
        // Rule 2: declining an invitation must not permanently block reconnection.
        #expect(PeerConnectionState.rejected.applying(.initiateConnection) == .connecting)
    }

    @Test func connecting_connectionAccepted_yieldsConnected() {
        #expect(PeerConnectionState.connecting.applying(.connectionAccepted) == .connected)
    }

    @Test func connecting_connectionDeclined_yieldsRejected() {
        #expect(PeerConnectionState.connecting.applying(.connectionDeclined) == .rejected)
    }

    @Test func connected_initiateDisconnection_yieldsIdle() {
        // Rule 3: the initiating side disconnects.
        #expect(PeerConnectionState.connected.applying(.initiateDisconnection) == .idle)
    }

    @Test func connected_peerDisconnected_yieldsIdle() {
        // Rule 3: the receiving side sees disconnection.
        #expect(PeerConnectionState.connected.applying(.peerDisconnected) == .idle)
    }

    // MARK: - Invalid transitions → nil

    @Test func connecting_initiateConnection_isInvalid() {
        #expect(PeerConnectionState.connecting.applying(.initiateConnection) == nil)
    }

    @Test func connected_initiateConnection_isInvalid() {
        #expect(PeerConnectionState.connected.applying(.initiateConnection) == nil)
    }

    @Test func idle_connectionAccepted_isInvalid() {
        #expect(PeerConnectionState.idle.applying(.connectionAccepted) == nil)
    }

    @Test func idle_peerDisconnected_isInvalid() {
        #expect(PeerConnectionState.idle.applying(.peerDisconnected) == nil)
    }

    @Test func idle_initiateDisconnection_isInvalid() {
        #expect(PeerConnectionState.idle.applying(.initiateDisconnection) == nil)
    }

    @Test func rejected_initiateDisconnection_isInvalid() {
        #expect(PeerConnectionState.rejected.applying(.initiateDisconnection) == nil)
    }

    // MARK: - Full reconnect flow (Rules 1 & 2 end-to-end)

    @Test func fullReconnectCycle() {
        // Connect → decline → reconnect → accept
        var state = PeerConnectionState.idle
        state = state.applying(.initiateConnection)!
        #expect(state == .connecting)
        state = state.applying(.connectionDeclined)!
        #expect(state == .rejected)
        // Rule 2: rejected → can try again
        state = state.applying(.initiateConnection)!
        #expect(state == .connecting)
        state = state.applying(.connectionAccepted)!
        #expect(state == .connected)
    }

    @Test func fullDisconnectCycle() {
        // Connect → accept → disconnect → reconnect (Rule 4)
        var state = PeerConnectionState.idle
        state = state.applying(.initiateConnection)!
        state = state.applying(.connectionAccepted)!
        #expect(state == .connected)
        // Rule 3: initiator disconnects
        state = state.applying(.initiateDisconnection)!
        #expect(state == .idle)
        // Rule 4: both sides back to normal, can reconnect
        #expect(state.applying(.initiateConnection) == .connecting)
    }
}
