import Foundation

/// Discovers peers' HTTP transfer servers on the local network and resolves
/// them to concrete host:port endpoints, keyed by the peer's stable deviceID.
@MainActor
protocol PeerEndpointResolving: AnyObject {
    func start()
    func stop()
    /// Synchronous cache lookup — kept warm by eager resolution as services
    /// appear, so the facade's synchronous send path can consult it directly.
    func cachedEndpoint(for deviceID: UUID) -> PeerEndpoint?
    /// Forces (re-)resolution; used by the retry path after `invalidate`.
    func resolveEndpoint(for deviceID: UUID) async -> PeerEndpoint?
    /// Drops a cached endpoint (e.g. after a connection failure) so the next
    /// lookup re-resolves — heals changed IPs/ports across app restarts.
    func invalidate(deviceID: UUID)
}
