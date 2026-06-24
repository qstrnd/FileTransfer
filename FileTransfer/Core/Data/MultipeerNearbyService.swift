import Foundation
import MultipeerConnectivity
import OSLog

/// Invitation timeout in seconds — shared between the MPC call and the VM failsafe.
let mcInvitationTimeout: TimeInterval = 30

@MainActor
final class MultipeerNearbyService: NSObject, NearbySessionService {
    // nonisolated so the logger is reachable from nonisolated MPC delegate callbacks.
    nonisolated private static let log = Logger(subsystem: "com.qstrnd.FileTransfer", category: "MPC")
    private static let serviceType = "ft-demo"
    nonisolated private static let discoveryKey: String = "deviceID"

    weak var delegate: (any NearbySessionServiceDelegate)?

    private var myPeerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    // Written from nonisolated MC callbacks; read from @MainActor methods.
    // nonisolated(unsafe) is safe here because writes happen-before the
    // @MainActor Task that reads them (structured sequencing via Task dispatch).
    nonisolated(unsafe) private var invitationHandler: ((Bool, MCSession?) -> Void)?
    nonisolated(unsafe) private var peerIDMap: [String: MCPeerID] = [:]
    nonisolated(unsafe) private var peerDeviceIDMap: [String: UUID] = [:]

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
        invitationHandler = nil; peerIDMap = [:]; peerDeviceIDMap = [:]
    }

    func connect(to peer: Peer) {
        guard let browser, let session, let peerID = peerIDMap[peer.id] else {
            MultipeerNearbyService.log.warning("connect — peerID not found for \(peer.displayName, privacy: .public)")
            return
        }
        MultipeerNearbyService.log.info("connect — inviting \(peer.displayName, privacy: .public) timeout=\(mcInvitationTimeout)s")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: mcInvitationTimeout)
    }

    func disconnect(from peer: Peer) {
        MultipeerNearbyService.log.info("disconnect — severing session for \(peer.displayName, privacy: .public) (affects all peers — MPC limitation)")
        // MCSession has no per-peer disconnect; disconnect() severs all active peers.
        // The remote side receives didChange(.notConnected) for our peerID.
        //
        // Intentionally do NOT clear peerIDMap / peerDeviceIDMap here.
        // The browser continues running and the peer stays in the map, so
        // a subsequent connect(to:) can immediately re-invite them without
        // waiting for another foundPeer callback (which may never fire if
        // the peer is still advertising nearby and lostPeer never triggered).
        session?.disconnect()
    }

    func send(text: String, to peer: Peer) {
        guard let session, let peerID = peerIDMap[peer.id], let data = text.data(using: .utf8) else {
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

    nonisolated private func peer(for peerID: MCPeerID) -> Peer {
        Peer(displayName: peerID.displayName, deviceID: peerDeviceIDMap[peerID.displayName])
    }
}

// MARK: - MCSessionDelegate

extension MultipeerNearbyService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let peer = peer(for: peerID)
        let label: String = switch state {
            case .connected:    "connected"
            case .connecting:   "connecting"
            case .notConnected: "notConnected"
            @unknown default:   "unknown"
        }
        MultipeerNearbyService.log.info("session didChange peer=\(peerID.displayName, privacy: .public) → \(label, privacy: .public)")
        // peerIDMap / peerDeviceIDMap are managed exclusively by the browser
        // callbacks (foundPeer adds, lostPeer removes). A session disconnect
        // does not mean the peer is undiscoverable — they are still nearby and
        // can be re-invited. Removing here was preventing reconnection.
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
        let peer = peer(for: peerID)
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
        peerIDMap[peerID.displayName] = peerID
        if let deviceID { peerDeviceIDMap[peerID.displayName] = deviceID }
        let peer = Peer(displayName: peerID.displayName, deviceID: deviceID)
        Task { @MainActor [weak self] in self?.delegate?.didDiscover(peer: peer) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        MultipeerNearbyService.log.info("lostPeer \(peerID.displayName, privacy: .public)")
        let peer = peer(for: peerID)
        peerIDMap.removeValue(forKey: peerID.displayName)
        peerDeviceIDMap.removeValue(forKey: peerID.displayName)
        Task { @MainActor [weak self] in self?.delegate?.didLose(peer: peer) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        MultipeerNearbyService.log.error("didNotStartBrowsing: \(error.localizedDescription, privacy: .public)")
    }
}
