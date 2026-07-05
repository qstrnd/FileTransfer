import Testing
import Foundation
@testable import FileTransfer

// MARK: - Spy

@MainActor
private final class SpyNearbyService: NearbySessionService {
    var delegate: (any NearbySessionServiceDelegate)?

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var acceptCallCount = 0
    private(set) var declineCallCount = 0
    private(set) var pingCalls: [Peer] = []
    private(set) var disconnectCalls: [Peer] = []
    private(set) var connectCalls: [(peer: Peer, isReconnect: Bool)] = []
    private(set) var sendTextCalls: [(text: String, peer: Peer)] = []

    func start(displayName: String, deviceID: UUID) { startCallCount += 1 }
    func stop() { stopCallCount += 1 }
    func connect(to peer: Peer, isReconnect: Bool) { connectCalls.append((peer, isReconnect)) }
    func send(text: String, to peer: Peer) { sendTextCalls.append((text, peer)) }
    func acceptInvitation() { acceptCallCount += 1 }
    func declineInvitation() { declineCallCount += 1 }
    func sendPing(to peer: Peer) { pingCalls.append(peer) }
    func disconnect(from peer: Peer) { disconnectCalls.append(peer) }
}

// MARK: - Tests

@MainActor
struct SearchViewModelTests {

    private let myDeviceID = UUID()

    private func makeVM(
        history: InMemoryConnectionHistoryStore = .init()
    ) -> (SearchViewModel, SpyNearbyService) {
        let service = SpyNearbyService()
        let vm = SearchViewModel(
            emoji: "🐟", name: "Fish",
            deviceID: myDeviceID,
            service: service,
            connectionHistory: history,
            historyStore: .preview,
            onBack: {}
        )
        return (vm, service)
    }

    private func peer(_ name: String = "🐟 Fish") -> Peer {
        Peer(displayName: name, deviceID: UUID())
    }

    // MARK: - Auto-reconnect

    @Test func manualDisconnect_suppressesAutoReconnect() async throws {
        // After a manual disconnect, a peer re-appearing in the same session must NOT
        // be auto-reconnected, even when all other conditions (known peer history,
        // isReturningFromBackground) would normally cause reconnect to fire.
        let history = InMemoryConnectionHistoryStore()
        let peerID = UUID()
        history.record(ConnectionRecord(deviceID: peerID, displayName: "🐟 Fish", lastConnected: .now))
        let (vm, service) = makeVM(history: history)
        let p = Peer(displayName: "🐟 Fish", deviceID: peerID)

        // handleForeground sets isReturningFromBackground = true so that — without
        // the suppression fix — auto-reconnect would fire on the next peerDiscovered.
        vm.handleForeground()

        // Simulate a successful connection without calling peerDiscovered, which
        // would create a dangling reconnect Task that could corrupt the assertion.
        vm.peerStates[p] = .connecting
        vm.peerConnected(p)

        // User manually disconnects — the event under test.
        vm.disconnect(from: p)
        vm.peerDisconnected(p)

        let connectsBefore = service.connectCalls.count

        // Peer leaves and re-appears within the same session.
        vm.peerLost(p)
        vm.peerDiscovered(p)

        // Allow the 500 ms reconnect window to elapse; if a Task were created
        // it would have called connect by now.
        try await Task.sleep(for: .milliseconds(700))

        #expect(service.connectCalls.count == connectsBefore,
                "no new connect expected after manual disconnect")
    }

    // MARK: - peerDiscovered

    @Test func peerDiscovered_selfDeviceID_isIgnored() {
        let (vm, _) = makeVM()
        let self_ = Peer(displayName: "🐟 Me", deviceID: myDeviceID)
        vm.peerDiscovered(self_)
        #expect(vm.discoveredPeers.isEmpty)
    }

    @Test func peerDiscovered_samePeerTwice_addedOnce() {
        let (vm, _) = makeVM()
        let p = peer()
        vm.peerDiscovered(p)
        vm.peerDiscovered(p)
        #expect(vm.discoveredPeers.count == 1)
    }

    @Test func peerDiscovered_cancelsDeferredLostPeer() {
        // If a transient lostPeer was deferred (peer was connected), and the peer
        // comes back via foundPeer before the session drops, the deferral is cancelled.
        // A subsequent peerDisconnected must then NOT evict the peer from the grid.
        let (vm, _) = makeVM()
        let p = peer()
        vm.peerDiscovered(p)
        vm.peerStates[p] = .connecting
        vm.peerConnected(p)

        vm.peerLost(p)           // deferred — peer is still connected
        #expect(vm.discoveredPeers.contains(p))

        vm.peerDiscovered(p)     // peer came back → cancel deferral

        vm.peerDisconnected(p)   // session drops; no pending loss → peer stays
        #expect(vm.discoveredPeers.contains(p))
    }

    // MARK: - peerLost

    @Test func peerLost_whileConnected_deferredAndStaysInGrid() {
        let (vm, _) = makeVM()
        let p = peer()
        vm.peerDiscovered(p)
        vm.peerStates[p] = .connecting
        vm.peerConnected(p)

        vm.peerLost(p)

        #expect(vm.discoveredPeers.contains(p), "eviction must be deferred while peer is connected")
    }

    @Test func peerLost_whileConnecting_deferredAndStaysInGrid() {
        let (vm, _) = makeVM()
        let p = peer()
        vm.peerDiscovered(p)
        vm.peerStates[p] = .connecting

        vm.peerLost(p)

        #expect(vm.discoveredPeers.contains(p), "eviction must be deferred while peer is connecting")
    }

    @Test func peerLost_whileIdle_immediatelyEvicted() {
        let (vm, _) = makeVM()
        let p = peer()
        vm.peerDiscovered(p)

        vm.peerLost(p)

        #expect(!vm.discoveredPeers.contains(p))
    }

    // MARK: - peerDisconnected

    @Test func peerDisconnected_withoutPriorLostPeer_peerRemainsInGrid() {
        // Regression: peerDisconnected must NOT remove the peer from discoveredPeers
        // when the browser never fired lostPeer (the peer is still advertising nearby).
        // MPC's browser is edge-triggered and won't re-fire foundPeer for a peer it
        // hasn't lost, so removing here would permanently hide the peer's bubble.
        let (vm, _) = makeVM()
        let p = peer()
        vm.peerDiscovered(p)
        vm.peerStates[p] = .connecting
        vm.peerConnected(p)

        vm.peerDisconnected(p)

        #expect(vm.discoveredPeers.contains(p), "peer must stay in grid so the user can reconnect")
    }

    @Test func peerDisconnected_afterDeferredLostPeer_evictsFromGrid() {
        // When both peerLost AND peerDisconnected fire (peer went fully away),
        // the deferred eviction must be flushed so the bubble is removed.
        let (vm, _) = makeVM()
        let p = peer()
        vm.peerDiscovered(p)
        vm.peerStates[p] = .connecting
        vm.peerConnected(p)

        vm.peerLost(p)          // deferred — peer connected at time of loss
        #expect(vm.discoveredPeers.contains(p))

        vm.peerDisconnected(p)  // flush deferred eviction

        #expect(!vm.discoveredPeers.contains(p), "peer must be evicted once session also drops")
    }

    @Test func peerDisconnected_fromConnectedState_setsDisconnectedPeerForToast() {
        let (vm, _) = makeVM()
        let p = peer()
        vm.peerDiscovered(p)
        vm.peerStates[p] = .connecting
        vm.peerConnected(p)

        vm.peerDisconnected(p)

        #expect(vm.disconnectedPeer == p)
    }

    // MARK: - invitationReceived

    @Test func invitationReceived_whenIdle_showsAlert() {
        let (vm, _) = makeVM()
        let p = peer()
        vm.peerDiscovered(p)

        vm.invitationReceived(from: p)

        #expect(vm.pendingInvitationFrom == p)
    }

    @Test func invitationReceived_whenConnecting_declines() {
        let (vm, service) = makeVM()
        let p = peer()
        vm.peerDiscovered(p)
        vm.peerStates[p] = .connecting

        vm.invitationReceived(from: p)

        #expect(service.declineCallCount == 1)
        #expect(vm.pendingInvitationFrom == nil)
    }

    @Test func invitationReceived_whenConnected_declines() {
        let (vm, service) = makeVM()
        let p = peer()
        vm.peerDiscovered(p)
        vm.peerStates[p] = .connecting
        vm.peerConnected(p)

        vm.invitationReceived(from: p)

        #expect(service.declineCallCount == 1)
    }

    // MARK: - reconnectInvitationReceived

    @Test func reconnectInvitationReceived_knownPeer_autoAcceptsWithoutAlert() {
        let history = InMemoryConnectionHistoryStore()
        let peerID = UUID()
        history.record(ConnectionRecord(deviceID: peerID, displayName: "🐟 Fish", lastConnected: .now))
        let (vm, service) = makeVM(history: history)
        let p = Peer(displayName: "🐟 Fish", deviceID: peerID)
        vm.peerDiscovered(p)

        vm.reconnectInvitationReceived(from: p)

        #expect(service.acceptCallCount == 1)
        #expect(vm.peerStates[p] == .connected)
        #expect(vm.pendingInvitationFrom == nil)
    }

    @Test func reconnectInvitationReceived_whenConnecting_declines() {
        let (vm, service) = makeVM()
        let p = peer()
        vm.peerDiscovered(p)
        vm.peerStates[p] = .connecting

        vm.reconnectInvitationReceived(from: p)

        #expect(service.declineCallCount == 1)
    }

    @Test func reconnectInvitationReceived_whenConnected_declines() {
        let (vm, service) = makeVM()
        let p = peer()
        vm.peerDiscovered(p)
        vm.peerStates[p] = .connecting
        vm.peerConnected(p)

        vm.reconnectInvitationReceived(from: p)

        #expect(service.declineCallCount == 1)
    }

    @Test func reconnectInvitationReceived_unknownPeer_fallsBackToManualAlert() {
        let (vm, _) = makeVM()   // empty history
        let p = peer()
        vm.peerDiscovered(p)

        vm.reconnectInvitationReceived(from: p)

        #expect(vm.pendingInvitationFrom == p)
    }

    @Test func reconnectInvitationReceived_recentlyLaunched_showsConnectionsRestoredToast() {
        let history = InMemoryConnectionHistoryStore()
        let peerID = UUID()
        history.record(ConnectionRecord(deviceID: peerID, displayName: "🐟 Fish", lastConnected: .now))
        let (vm, _) = makeVM(history: history)
        let p = Peer(displayName: "🐟 Fish", deviceID: peerID)

        vm.start()               // sets isRecentlyLaunched = true for 10 s
        vm.peerDiscovered(p)
        vm.reconnectInvitationReceived(from: p)

        #expect(vm.connectionsRestored == true)
        #expect(vm.reconnectedPeer == nil)
    }

    @Test func reconnectInvitationReceived_notRecentlyLaunched_showsReconnectedPeerToast() {
        let history = InMemoryConnectionHistoryStore()
        let peerID = UUID()
        history.record(ConnectionRecord(deviceID: peerID, displayName: "🐟 Fish", lastConnected: .now))
        let (vm, _) = makeVM(history: history)
        let p = Peer(displayName: "🐟 Fish", deviceID: peerID)

        // Do NOT call start() → isRecentlyLaunched remains false
        vm.peerDiscovered(p)
        vm.reconnectInvitationReceived(from: p)

        #expect(vm.reconnectedPeer == p)
        #expect(vm.connectionsRestored == false)
    }

    // MARK: - handleBackground

    @Test func handleBackground_clearsDiscoveryState() {
        let (vm, _) = makeVM()
        let p = peer()
        vm.peerDiscovered(p)
        vm.peerStates[p] = .connecting

        vm.handleBackground()

        #expect(vm.discoveredPeers.isEmpty)
        #expect(vm.peerStates.isEmpty)
    }

    @Test func handleBackground_stopsService() {
        let (vm, service) = makeVM()
        vm.handleBackground()
        #expect(service.stopCallCount == 1)
    }

    @Test func handleBackground_clearsPendingInvitation() {
        let (vm, _) = makeVM()
        let p = peer()
        vm.peerDiscovered(p)
        vm.invitationReceived(from: p)
        #expect(vm.pendingInvitationFrom != nil)

        vm.handleBackground()

        #expect(vm.pendingInvitationFrom == nil)
    }

    // MARK: - sendText

    @Test func sendText_multipleConnectedPeers_createsSingleRecordWithAllPeers() {
        let (vm, service) = makeVM()
        let p1 = peer("🐟 Fish")
        let p2 = peer("🦊 Fox")
        vm.peerStates[p1] = .connected
        vm.peerStates[p2] = .connected

        vm.sendText("Hello there!")

        #expect(vm.transferHistory.count == 1, "sending to multiple peers must create one history entry, not one per peer")
        #expect(vm.transferHistory.first?.peers.count == 2)
        #expect(service.sendTextCalls.count == 2, "the message must still be sent to every connected peer individually")
    }

    @Test func sendText_singleConnectedPeer_createsRecordWithThatPeer() {
        let (vm, _) = makeVM()
        let p = peer("🐟 Fish")
        vm.peerStates[p] = .connected

        vm.sendText("Hello there!")

        #expect(vm.transferHistory.count == 1)
        #expect(vm.transferHistory.first?.peers == [p])
    }

    @Test func sendText_noConnectedPeers_addsNoRecord() {
        let (vm, _) = makeVM()

        vm.sendText("Hello there!")

        #expect(vm.transferHistory.isEmpty)
    }

    @Test func sendText_blankText_addsNoRecord() {
        let (vm, _) = makeVM()
        vm.peerStates[peer()] = .connected

        vm.sendText("   ")

        #expect(vm.transferHistory.isEmpty)
    }

    // MARK: - Keepalive (5 s ping interval, 15 s disconnect threshold)

    @Test func checkKeepalive_freshPong_sendsPing() {
        let (vm, service) = makeVM()
        let p = peer()
        vm.peerDiscovered(p)
        vm.peerStates[p] = .connecting
        vm.peerConnected(p)          // records lastPongReceived[p.id] = .now
        let T0 = Date.now

        vm.checkKeepalive(now: T0.addingTimeInterval(5))

        #expect(service.pingCalls.contains(p))
        #expect(service.disconnectCalls.isEmpty)
    }

    @Test func checkKeepalive_stalePong_disconnects() {
        let (vm, service) = makeVM()
        let p = peer()
        vm.peerDiscovered(p)
        vm.peerStates[p] = .connecting
        vm.peerConnected(p)          // records lastPongReceived[p.id] = .now
        let T0 = Date.now

        vm.checkKeepalive(now: T0.addingTimeInterval(16))   // exceeds 15 s threshold

        #expect(service.disconnectCalls.contains(p))
        #expect(service.pingCalls.isEmpty)
    }

    @Test func checkKeepalive_noConnectedPeers_noop() {
        let (vm, service) = makeVM()

        vm.checkKeepalive(now: .now)

        #expect(service.pingCalls.isEmpty)
        #expect(service.disconnectCalls.isEmpty)
    }
}
