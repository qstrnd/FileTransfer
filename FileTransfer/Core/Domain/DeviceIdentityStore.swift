import Foundation

/// Provides the stable UUID that identifies this device across sessions.
/// The UUID is generated once on first access and persisted permanently.
protocol DeviceIdentityStore {
    /// The device's unique identifier. Guaranteed to be the same value
    /// for every call within a given installation.
    var deviceID: UUID { get }
}
