import Foundation

final class UserDefaultsUserProfileStore: UserProfileStore {
    private let defaults: UserDefaults
    private let key = "ft.userProfile"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var savedProfile: UserProfile? {
        guard let data = defaults.data(forKey: key),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return nil }
        return profile
    }

    func save(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: key)
        }
    }
}
