import Foundation
import MultipeerConnectivity

@MainActor
final class MultipeerNearbyService: NSObject, NearbySessionService {
    private static let serviceType = "ft-demo"
    nonisolated private static let discoveryDeviceIDKey: String = "deviceID"

    weak var delegate: (any NearbySessionServiceDelegate)?

    private var myPeerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    // Written from nonisolated MC callbacks, read from @MainActor methods.
    // nonisolated(unsafe) documents that we own the safety guarantee: writes
    // happen-before the @MainActor task that reads them.
    nonisolated(unsafe) private var invitationHandler: ((Bool, MCSession?) -> Void)?
    /// Maps displayName → MCPeerID for outgoing connect/send calls.
    nonisolated(unsafe) private var peerIDMap: [String: MCPeerID] = [:]
    /// Maps displayName → UUID parsed from MPC discoveryInfo.
    nonisolated(unsafe) private var peerDeviceIDMap: [String: UUID] = [:]

    func start(displayName: String, deviceID: UUID) {
        let peerID = MCPeerID(displayName: displayName)
        myPeerID = peerID

        let newSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        newSession.delegate = self
        session = newSession

        // Broadcast our UUID so remote peers can match us against their history.
        let info = [Self.discoveryDeviceIDKey: deviceID.uuidString]
        let newAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: info, serviceType: Self.serviceType)
        newAdvertiser.delegate = self
        newAdvertiser.startAdvertisingPeer()
        advertiser = newAdvertiser

        let newBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        newBrowser.delegate = self
        newBrowser.startBrowsingForPeers()
        browser = newBrowser
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        myPeerID = nil
        invitationHandler = nil
        peerIDMap = [:]
        peerDeviceIDMap = [:]
    }

    func connect(to peer: Peer) {
        guard let browser, let session, let peerID = peerIDMap[peer.id] else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func send(text: String, to peer: Peer) {
        guard let session,
              let peerID = peerIDMap[peer.id],
              let data = text.data(using: .utf8) else { return }
        try? session.send(data, toPeers: [peerID], with: .reliable)
    }

    func acceptInvitation() {
        invitationHandler?(true, session)
        invitationHandler = nil
    }

    func declineInvitation() {
        invitationHandler?(false, nil)
        invitationHandler = nil
    }

    // MARK: - Private helpers

    nonisolated private func peer(for peerID: MCPeerID) -> Peer {
        Peer(displayName: peerID.displayName, deviceID: peerDeviceIDMap[peerID.displayName])
    }
}

// MARK: - MCSessionDelegate

extension MultipeerNearbyService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let peer = peer(for: peerID)
        if state == .notConnected {
            peerIDMap.removeValue(forKey: peer.id)
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch state {
            case .connected:    delegate?.didConnect(peer: peer)
            case .notConnected: delegate?.didDisconnect(peer: peer)
            default:            break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        let message = TransferMessage(senderName: peerID.displayName, text: text)
        Task { @MainActor [weak self] in
            self?.delegate?.didReceive(message: message)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerNearbyService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let peer = peer(for: peerID)
        self.invitationHandler = invitationHandler
        Task { @MainActor [weak self] in
            self?.delegate?.didReceiveInvitation(from: peer)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("MPC advertising error: \(error)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerNearbyService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        // Parse the remote device's UUID from discoveryInfo if present.
        let deviceID = info?[MultipeerNearbyService.discoveryDeviceIDKey].flatMap(UUID.init(uuidString:))
        peerIDMap[peerID.displayName] = peerID
        if let deviceID { peerDeviceIDMap[peerID.displayName] = deviceID }
        let peer = Peer(displayName: peerID.displayName, deviceID: deviceID)
        Task { @MainActor [weak self] in
            self?.delegate?.didDiscover(peer: peer)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        let peer = peer(for: peerID)
        peerIDMap.removeValue(forKey: peerID.displayName)
        peerDeviceIDMap.removeValue(forKey: peerID.displayName)
        Task { @MainActor [weak self] in
            self?.delegate?.didLose(peer: peer)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("MPC browsing error: \(error)")
    }
}
