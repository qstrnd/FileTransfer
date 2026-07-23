import Foundation

/// Confirms whether local network access is actually usable. Neither iOS nor
/// macOS expose a direct authorization-status API for the Local Network
/// permission (unlike camera/microphone), so conformers infer it indirectly —
/// e.g. by probing self-discovery over Bonjour.
@MainActor
protocol LocalNetworkAccessGate: AnyObject {
    /// Starts a fresh check. Calls `onResult` exactly once with `true` if
    /// access is confirmed within `timeout`, `false` otherwise (permission
    /// denied/undetermined, or no local network interface at all — the two
    /// can't be told apart from this signal alone).
    func check(timeout: TimeInterval, onResult: @escaping (Bool) -> Void)
    func stop()
}
