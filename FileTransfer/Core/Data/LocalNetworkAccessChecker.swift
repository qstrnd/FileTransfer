import Foundation
import Network
import OSLog

/// Probes local network access via self-discovery: advertises a throwaway
/// Bonjour service and checks whether our own browser sees it come back.
/// This is the standard workaround for the missing authorization-status API —
/// see `LocalNetworkAccessGate`.
///
/// Reuses `HTTPFileTransferServer.bonjourServiceType` so no extra
/// `NSBonjourServices` entry is needed. The probe's instance name is
/// deliberately not a UUID (unlike the real server's), so it never matches
/// `BonjourPeerEndpointResolver`'s `UUID(uuidString:)` filter and can't be
/// mistaken for a peer by the real discovery pipeline running alongside it.
@MainActor
final class LocalNetworkAccessChecker: LocalNetworkAccessGate {
    nonisolated private static let log = Logger(subsystem: "com.qstrnd.FileTransfer", category: "LocalNetworkAccess")

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var timeoutTask: Task<Void, Never>?
    private var probeName: String?
    private var completion: ((Bool) -> Void)?

    func check(timeout: TimeInterval, onResult: @escaping (Bool) -> Void) {
        stop()
        let probeName = "lnp-\(UUID().uuidString)"
        self.probeName = probeName
        self.completion = onResult

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        guard let listener = try? NWListener(using: parameters) else {
            Self.log.error("failed to create probe listener")
            finish(false)
            return
        }
        listener.service = NWListener.Service(
            name: probeName, type: HTTPFileTransferServer.bonjourServiceType, txtRecord: NWTXTRecord()
        )
        listener.newConnectionHandler = { $0.cancel() }
        listener.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                Self.log.warning("probe listener failed: \(error.localizedDescription, privacy: .public)")
                Task { @MainActor [weak self] in self?.finish(false) }
            }
        }
        listener.start(queue: .main)
        self.listener = listener

        let browser = NWBrowser(for: .bonjour(type: HTTPFileTransferServer.bonjourServiceType, domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in self?.handleBrowseResults(results) }
        }
        browser.start(queue: .main)
        self.browser = browser

        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(timeout))
            guard !Task.isCancelled else { return }
            self?.finish(false)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        browser?.cancel()
        browser = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        probeName = nil
        completion = nil
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        guard let probeName else { return }
        let foundSelf = results.contains { result in
            if case .service(let name, _, _, _) = result.endpoint { return name == probeName }
            return false
        }
        if foundSelf { finish(true) }
    }

    private func finish(_ result: Bool) {
        guard let completion else { return }
        self.completion = nil
        stop()
        completion(result)
    }
}
