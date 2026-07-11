import Foundation
import Testing
@testable import FileTransfer

struct TransportPolicyTests {

    private let endpoint = PeerEndpoint(host: "192.168.1.10", port: 54321)
    private let policy = DefaultTransportPolicy()

    @Test func media_withEndpoint_prefersHTTP() {
        #expect(policy.transport(payload: .media, totalBytes: 1_000_000, endpoint: endpoint) == .http(endpoint))
    }

    @Test func file_withEndpoint_prefersHTTP() {
        #expect(policy.transport(payload: .file, totalBytes: 1_000, endpoint: endpoint) == .http(endpoint))
    }

    @Test func media_withoutEndpoint_fallsBackToMPC() {
        #expect(policy.transport(payload: .media, totalBytes: 1_000_000, endpoint: nil) == .multipeer)
    }

    @Test func controlPayloads_alwaysMPC_evenWithEndpoint() {
        #expect(policy.transport(payload: .text, totalBytes: 10, endpoint: endpoint) == .multipeer)
        #expect(policy.transport(payload: .contact, totalBytes: 10_000, endpoint: endpoint) == .multipeer)
        #expect(policy.transport(payload: .control, totalBytes: 3, endpoint: endpoint) == .multipeer)
    }

    @Test func minimumBytesThreshold_routesSmallPayloadsToMPC() {
        let thresholdPolicy = DefaultTransportPolicy(httpMinimumBytes: 1_000_000)
        #expect(thresholdPolicy.transport(payload: .media, totalBytes: 999_999, endpoint: endpoint) == .multipeer)
        #expect(thresholdPolicy.transport(payload: .media, totalBytes: 1_000_000, endpoint: endpoint) == .http(endpoint))
    }
}

struct PeerEndpointTests {

    @Test func ipv4BaseURL() {
        let url = PeerEndpoint(host: "192.168.1.10", port: 8080).baseURL
        #expect(url?.absoluteString == "http://192.168.1.10:8080")
    }

    @Test func ipv6BaseURL_isBracketed() {
        let url = PeerEndpoint(host: "fe80::1c2a:3bff:fe4d:5e6f", port: 8080).baseURL
        #expect(url?.absoluteString == "http://[fe80::1c2a:3bff:fe4d:5e6f]:8080")
    }

    @Test func ipv6WithZone_escapesPercent() {
        let url = PeerEndpoint(host: "fe80::1%en0", port: 443).baseURL
        #expect(url?.absoluteString == "http://[fe80::1%25en0]:443")
    }

    @Test func uploadURLComposition() {
        let base = PeerEndpoint(host: "10.0.0.2", port: 5000).baseURL
        let full = base.flatMap { URL(string: "/v1/transfer", relativeTo: $0) }
        #expect(full?.absoluteString == "http://10.0.0.2:5000/v1/transfer")
    }
}
