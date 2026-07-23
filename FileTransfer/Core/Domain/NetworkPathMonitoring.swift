import Foundation

/// Notifies whenever the OS-reported network path changes — e.g. Wi-Fi or
/// Airplane Mode toggled from Control Center, which doesn't background the
/// app and so isn't caught by a scene-phase-driven recheck alone.
@MainActor
protocol NetworkPathMonitoring: AnyObject {
    /// Fires on every path change while monitoring. Not itself a reachability
    /// verdict — just a hint that `LocalNetworkAccessGate.check` is worth
    /// re-running.
    var onChange: (() -> Void)? { get set }
    func start()
    func stop()
}
