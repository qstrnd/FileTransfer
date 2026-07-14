import Foundation

/// Compile-time feature flags for the transfer stack — the single place to
/// toggle capabilities while they're being stabilized. Flip a constant and
/// rebuild; no runtime configuration.
nonisolated enum TransferFeatureFlags {
    /// HTTP data plane as the preferred bulk transport (with MPC fallback):
    /// the local-network upload server, Bonjour endpoint resolution, and
    /// media/file routing over HTTP. When off, every payload rides MPC and
    /// no server is started or advertised.
    static let httpDataPlane = true

    /// Transfer continuation across app backgrounding (background URLSession
    /// uploads, receiver drain under a background task) plus Live Activity
    /// progress on the lock screen / Dynamic Island. When off, uploads use a
    /// regular foreground session, stop() tears the server down immediately,
    /// and no activities are requested.
    static let backgroundTransferAndLiveActivity = false

    /// Contact sharing (the "Contact" share action). SUSPENDED: the feature is
    /// no longer supported — its entry point is hidden while this is off. Do
    /// not build on it or reintroduce contact-send UI without re-enabling here.
    static let contactSharing = false
}
