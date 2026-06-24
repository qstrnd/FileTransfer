import Foundation

/// The user's chosen display identity — persisted after the first onboarding completion.
struct UserProfile: Codable, Equatable, Sendable {
    let emoji: String
    let name: String
}

/// Read/write access to the saved user profile.
protocol UserProfileStore {
    /// Returns the saved profile, or nil if onboarding has never been completed.
    var savedProfile: UserProfile? { get }
    func save(_ profile: UserProfile)
}
