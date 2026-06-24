import Foundation

/// Persists the device UUID in `UserDefaults`.
/// The UUID is created on first access and never replaced.
final class UserDefaultsDeviceIdentityStore: DeviceIdentityStore {
    private let defaults: UserDefaults
    private let key = "ft.deviceIdentity.uuid"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Eagerly generate so future reads are always non-nil.
        if defaults.string(forKey: key) == nil {
            defaults.set(UUID().uuidString, forKey: key)
        }
    }

    var deviceID: UUID {
        if let raw = defaults.string(forKey: key), let uuid = UUID(uuidString: raw) {
            return uuid
        }
        // Safety net: should never reach here given the eager init above.
        let uuid = UUID()
        defaults.set(uuid.uuidString, forKey: key)
        return uuid
    }
}
