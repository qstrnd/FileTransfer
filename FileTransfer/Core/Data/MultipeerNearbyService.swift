import Foundation
import MultipeerConnectivity

final class MultipeerNearbyService: NSObject, NearbySessionService {
    private static let serviceType = "ft-demo"

    weak var delegate: (any NearbySessionServiceDelegate)?

    private var myPeerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var invitationHandler: ((Bool, MCSession?) -> Void)?
    private var peerIDMap: [String: MCPeerID] = [:]

    func start(displayName: String) {
        let peerID = MCPeerID(displayName: displayName)
        myPeerID = peerID

        let newSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        newSession.delegate = self
        session = newSession

        let newAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: Self.serviceType)
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
}

extension MultipeerNearbyService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let peer = Peer(displayName: peerID.displayName)
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch state {
            case .connected:
                delegate?.didConnect(peer: peer)
            case .notConnected:
                peerIDMap.removeValue(forKey: peer.id)
                delegate?.didDisconnect(peer: peer)
            default:
                break
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

extension MultipeerNearbyService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let peer = Peer(displayName: peerID.displayName)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.invitationHandler = invitationHandler
            delegate?.didReceiveInvitation(from: peer)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("MPC advertising error: \(error)")
    }
}

extension MultipeerNearbyService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let peer = Peer(displayName: peerID.displayName)
        Task { @MainActor [weak self] in
            guard let self else { return }
            peerIDMap[peer.id] = peerID
            delegate?.didDiscover(peer: peer)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        let peer = Peer(displayName: peerID.displayName)
        Task { @MainActor [weak self] in
            guard let self else { return }
            peerIDMap.removeValue(forKey: peer.id)
            delegate?.didLose(peer: peer)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("MPC browsing error: \(error)")
    }
}
