import Foundation

/// Decides which transport carries a payload to a peer. Pure — all inputs are
/// passed in, so decisions are deterministic and unit-testable.
nonisolated protocol TransportPolicy: Sendable {
    func transport(payload: TransferPayloadKind, totalBytes: Int64, endpoint: PeerEndpoint?) -> TransferTransport
}

/// Default rules:
/// - `text`/`contact`/`control` always ride MPC — they're tiny, and MPC's
///   session is already the control plane. (The facade doesn't even consult
///   the policy for them; the case exists so the decision table is complete.)
/// - `media`/`file` prefer HTTP when the peer's endpoint is resolved and the
///   payload meets `httpMinimumBytes`; otherwise MPC.
///
/// A nil endpoint funnels every HTTP precondition through one gate: peer has
/// no deviceID (legacy build), Bonjour hasn't resolved yet, or the service
/// disappeared from the network.
nonisolated struct DefaultTransportPolicy: TransportPolicy {
    /// Bulk payloads below this ride MPC even when HTTP is available —
    /// connection setup would dominate for tiny payloads. 0 = always HTTP.
    var httpMinimumBytes: Int64 = 0

    func transport(payload: TransferPayloadKind, totalBytes: Int64, endpoint: PeerEndpoint?) -> TransferTransport {
        switch payload {
        case .text, .contact, .control:
            return .multipeer
        case .media, .file:
            guard let endpoint, totalBytes >= httpMinimumBytes else { return .multipeer }
            return .http(endpoint)
        }
    }
}
