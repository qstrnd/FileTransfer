import Foundation
import Network
import OSLog

/// Browses `_ftdata._tcp` and resolves each peer's transfer server to a
/// concrete host:port, keyed by the deviceID UUID that the server uses as its
/// Bonjour service instance name.
///
/// Resolution strategy: MPC cannot expose peer IP addresses, and a background
/// `URLSessionUploadTask` needs a literal `http://host:port` URL — so when a
/// browse result appears we eagerly open a short-lived probe `NWConnection`
/// to the service endpoint, read the resolved remote host:port off its path
/// on `.ready`, cache it, and cancel the probe. Eager resolution keeps
/// `cachedEndpoint(for:)` warm for the facade's synchronous send path.
@MainActor
final class BonjourPeerEndpointResolver: PeerEndpointResolving {
    nonisolated private static let log = Logger(subsystem: "com.qstrnd.FileTransfer", category: "EndpointResolver")

    private var browser: NWBrowser?
    private var cache: [UUID: PeerEndpoint] = [:]
    /// Browse results by deviceID, kept for on-demand (re-)resolution.
    private var knownServices: [UUID: NWEndpoint] = [:]
    private var probes: [UUID: NWConnection] = [:]
    private var resolutionWaiters: [UUID: [CheckedContinuation<PeerEndpoint?, Never>]] = [:]

    // MARK: - PeerEndpointResolving

    func start() {
        guard browser == nil else { return }
        let browser = NWBrowser(
            for: .bonjour(type: HTTPFileTransferServer.bonjourServiceType, domain: nil),
            using: .tcp
        )
        browser.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                Self.log.error("browser failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let snapshot = results.map(\.endpoint)
            Task { @MainActor [weak self] in
                self?.browseResultsChanged(snapshot)
            }
        }
        browser.start(queue: .main)
        self.browser = browser
        Self.log.info("browser started")
    }

    func stop() {
        browser?.cancel()
        browser = nil
        for probe in probes.values { probe.cancel() }
        probes.removeAll()
        cache.removeAll()
        knownServices.removeAll()
        for waiters in resolutionWaiters.values {
            for waiter in waiters { waiter.resume(returning: nil) }
        }
        resolutionWaiters.removeAll()
    }

    func cachedEndpoint(for deviceID: UUID) -> PeerEndpoint? {
        cache[deviceID]
    }

    func resolveEndpoint(for deviceID: UUID) async -> PeerEndpoint? {
        if let cached = cache[deviceID] { return cached }
        guard let service = knownServices[deviceID] else { return nil }
        return await withCheckedContinuation { continuation in
            resolutionWaiters[deviceID, default: []].append(continuation)
            resolve(deviceID: deviceID, service: service)
        }
    }

    func invalidate(deviceID: UUID) {
        cache[deviceID] = nil
        probes[deviceID]?.cancel()
        probes[deviceID] = nil
    }

    // MARK: - Browse + resolve

    private func browseResultsChanged(_ endpoints: [NWEndpoint]) {
        var current: [UUID: NWEndpoint] = [:]
        for endpoint in endpoints {
            guard case .service(let name, _, _, _) = endpoint,
                  let deviceID = UUID(uuidString: name) else { continue }
            current[deviceID] = endpoint
        }

        // Services that vanished: drop cache so sends fall back to MPC and a
        // reappearing service re-resolves (fresh port after listener restart).
        for stale in knownServices.keys where current[stale] == nil {
            Self.log.info("service lost for \(stale, privacy: .public)")
            invalidate(deviceID: stale)
        }

        for (deviceID, endpoint) in current where knownServices[deviceID] == nil || cache[deviceID] == nil {
            resolve(deviceID: deviceID, service: endpoint)
        }
        knownServices = current
    }

    private func resolve(deviceID: UUID, service: NWEndpoint) {
        guard probes[deviceID] == nil else { return } // already resolving

        let probe = NWConnection(to: service, using: .tcp)
        probes[deviceID] = probe
        probe.stateUpdateHandler = { [weak self, weak probe] state in
            switch state {
            case .ready:
                let remote = probe?.currentPath?.remoteEndpoint
                Task { @MainActor [weak self] in
                    self?.probeCompleted(deviceID: deviceID, remote: remote)
                }
            case .failed(let error):
                Self.log.warning("probe failed for \(deviceID, privacy: .public): \(error.localizedDescription, privacy: .public)")
                Task { @MainActor [weak self] in
                    self?.probeCompleted(deviceID: deviceID, remote: nil)
                }
            default:
                break
            }
        }
        probe.start(queue: .main)
    }

    private func probeCompleted(deviceID: UUID, remote: NWEndpoint?) {
        probes[deviceID]?.cancel()
        probes[deviceID] = nil

        var endpoint: PeerEndpoint?
        if case .hostPort(let host, let port) = remote {
            let hostString: String
            switch host {
            case .ipv4(let address): hostString = "\(address)"
            case .ipv6(let address): hostString = "\(address)"
            case .name(let name, _): hostString = name
            @unknown default:        hostString = "\(host)"
            }
            // NWEndpoint.Host's description can carry an interface suffix
            // (e.g. "192.168.1.5%en0"); keep it — PeerEndpoint.baseURL escapes it.
            endpoint = PeerEndpoint(host: hostString, port: port.rawValue)
        }

        if let endpoint {
            Self.log.info("resolved \(deviceID, privacy: .public) → \(endpoint.host, privacy: .public):\(endpoint.port)")
            cache[deviceID] = endpoint
        }
        for waiter in resolutionWaiters.removeValue(forKey: deviceID) ?? [] {
            waiter.resume(returning: endpoint)
        }
    }
}
