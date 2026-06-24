import Foundation
import MultipeerConnectivity
import OSLog

/// Invitation timeout in seconds — shared between the MPC call and the VM failsafe.
let mcInvitationTimeout: TimeInterval = 30

@MainActor
final class MultipeerNearbyService: NSObject, NearbySessionService {
    nonisolated private static let log = Logger(subsystem: "com.qstrnd.FileTransfer", category: "MPC")
    private static let serviceType = "ft-demo"
    nonisolated private static let discoveryKey: String = "deviceID"

    weak var delegate: (any NearbySessionServiceDelegate)?

    private var myPeerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    // nonisolated(unsafe): written from nonisolated MC callbacks, read on @MainActor.
    // Safety: writes happen-before the @MainActor Task that reads them.
    nonisolated(unsafe) private var invitationHandler: ((Bool, MCSession?) -> Void)?
    // PeerRegistry owns the discovery map. Session events must NOT mutate it —
    // only browser events (foundPeer/lostPeer) and stop() do. See PeerRegistry.swift.
    nonisolated(unsafe) private var registry = PeerRegistry()

    // MARK: - NearbySessionService

    func start(displayName: String, deviceID: UUID) {
        MultipeerNearbyService.log.info("start displayName=\(displayName, privacy: .public) deviceID=\(deviceID, privacy: .public)")
        let peerID = MCPeerID(displayName: displayName)
        myPeerID = peerID

        let newSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        newSession.delegate = self
        session = newSession

        let info = [Self.discoveryKey: deviceID.uuidString]
        let newAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: info, serviceType: Self.serviceType)
        newAdvertiser.delegate = self
        newAdvertiser.startAdvertisingPeer()
        advertiser = newAdvertiser

        let newBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        newBrowser.delegate = self
        newBrowser.startBrowsingForPeers()
        browser = newBrowser
        MultipeerNearbyService.log.debug("advertiser + browser started")
    }

    func stop() {
        MultipeerNearbyService.log.info("stop")
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil; browser = nil; session = nil; myPeerID = nil
        invitationHandler = nil
        registry.reset()
    }

    func connect(to peer: Peer) {
        guard let browser, let session, let peerID = registry.mcPeerID(for: peer.id) else {
            MultipeerNearbyService.log.warning("connect — peerID not found for \(peer.displayName, privacy: .public)")
            return
        }
        MultipeerNearbyService.log.info("connect — inviting \(peer.displayName, privacy: .public) timeout=\(mcInvitationTimeout)s")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: mcInvitationTimeout)
    }

    func disconnect(from peer: Peer) {
        MultipeerNearbyService.log.info("disconnect — severing session for \(peer.displayName, privacy: .public) (MCSession has no per-peer API)")
        // session.disconnect() severs all active peers and fires .notConnected
        // on both sides, but does NOT modify the registry — peer remains
        // available for re-invitation without needing rediscovery.
        session?.disconnect()
    }

    func send(text: String, to peer: Peer) {
        guard let session, let peerID = registry.mcPeerID(for: peer.id), let data = text.data(using: .utf8) else {
            MultipeerNearbyService.log.warning("send — prerequisites missing for \(peer.displayName, privacy: .public)")
            return
        }
        MultipeerNearbyService.log.debug("send \(data.count)B to \(peer.displayName, privacy: .public)")
        try? session.send(data, toPeers: [peerID], with: .reliable)
    }

    func acceptInvitation() {
        MultipeerNearbyService.log.info("acceptInvitation")
        invitationHandler?(true, session)
        invitationHandler = nil
    }

    func declineInvitation() {
        MultipeerNearbyService.log.info("declineInvitation")
        invitationHandler?(false, nil)
        invitationHandler = nil
    }
}

// MARK: - MCSessionDelegate

extension MultipeerNearbyService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let peer = registry.peer(for: peerID)
        let label: String = switch state {
            case .connected:    "connected"
            case .connecting:   "connecting"
            case .notConnected: "notConnected"
            @unknown default:   "unknown"
        }
        MultipeerNearbyService.log.info("session didChange peer=\(peerID.displayName, privacy: .public) → \(label, privacy: .public)")
        // Registry is NOT modified here. See PeerRegistry for the ownership rule.
        Task { @MainActor [weak self] in
            switch state {
            case .connected:    self?.delegate?.didConnect(peer: peer)
            case .notConnected: self?.delegate?.didDisconnect(peer: peer)
            default:            break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        MultipeerNearbyService.log.debug("didReceive \(data.count)B from \(peerID.displayName, privacy: .public)")
        let message = TransferMessage(senderName: peerID.displayName, text: text)
        Task { @MainActor [weak self] in self?.delegate?.didReceive(message: message) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerNearbyService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let peer = registry.peer(for: peerID)
        MultipeerNearbyService.log.info("didReceiveInvitation from \(peerID.displayName, privacy: .public)")
        self.invitationHandler = invitationHandler
        Task { @MainActor [weak self] in self?.delegate?.didReceiveInvitation(from: peer) }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        MultipeerNearbyService.log.error("didNotStartAdvertising: \(error.localizedDescription, privacy: .public)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerNearbyService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let deviceID = info?[MultipeerNearbyService.discoveryKey].flatMap(UUID.init(uuidString:))
        MultipeerNearbyService.log.info("foundPeer \(peerID.displayName, privacy: .public) deviceID=\(deviceID?.uuidString ?? "nil", privacy: .public)")
        registry.peerFound(peerID, deviceID: deviceID)
        let peer = registry.peer(for: peerID)
        Task { @MainActor [weak self] in self?.delegate?.didDiscover(peer: peer) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        MultipeerNearbyService.log.info("lostPeer \(peerID.displayName, privacy: .public)")
        let peer = registry.peer(for: peerID)
        registry.peerLost(displayName: peerID.displayName)
        Task { @MainActor [weak self] in self?.delegate?.didLose(peer: peer) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        MultipeerNearbyService.log.error("didNotStartBrowsing: \(error.localizedDescription, privacy: .public)")
    }
}
