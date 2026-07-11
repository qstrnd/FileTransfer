import Foundation

/// A peer's resolved HTTP upload endpoint on the local network.
nonisolated struct PeerEndpoint: Sendable, Equatable {
    let host: String
    let port: UInt16

    /// Base URL for upload requests. IPv6 hosts are bracketed; link-local
    /// zone IDs (`%en0`) are percent-encoded as URLs require.
    var baseURL: URL? {
        let urlHost: String
        if host.contains(":") {
            let escapedZone = host.replacingOccurrences(of: "%", with: "%25")
            urlHost = "[\(escapedZone)]"
        } else {
            urlHost = host
        }
        return URL(string: "http://\(urlHost):\(port)")
    }
}

/// What kind of payload a transport decision is being made for.
nonisolated enum TransferPayloadKind: Sendable {
    case media, file, text, contact, control
}

/// The route chosen for a payload.
nonisolated enum TransferTransport: Sendable, Equatable {
    case http(PeerEndpoint)
    case multipeer
}
