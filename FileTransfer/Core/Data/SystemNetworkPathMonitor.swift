import Foundation
import Network

/// Wraps `NWPathMonitor` to notify on real network-path transitions, so
/// `SearchViewModel` can recheck local network access exactly when something
/// actually changed instead of on a fixed timer.
@MainActor
final class SystemNetworkPathMonitor: NetworkPathMonitoring {
    private let monitor = NWPathMonitor()
    var onChange: (() -> Void)?

    func start() {
        monitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.onChange?()
            }
        }
        monitor.start(queue: .main)
    }

    func stop() {
        monitor.cancel()
    }
}
