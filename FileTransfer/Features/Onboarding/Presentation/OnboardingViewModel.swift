import Foundation
import Observation

enum IdentitySource: Equatable {
    case device
    case random
    case custom
}

@Observable
final class OnboardingViewModel {
    private(set) var source: IdentitySource = .device
    private(set) var emoji: String
    private(set) var name: String

    private let onProceed: (String, String) -> Void
    private let deviceInfo: () -> DeviceInfo.Identity

    /// - Parameters:
    ///   - initialProfile: When provided (e.g. returning from SearchView),
    ///     the onboarding opens pre-filled with the user's existing profile instead
    ///     of the device defaults.
    ///   - deviceInfo: Supplies the device identity. Injectable so the
    ///     device-info comparison can be unit-tested without touching UIKit.
    init(
        onProceed: @escaping (String, String) -> Void,
        initialProfile: UserProfile? = nil,
        deviceInfo: @escaping () -> DeviceInfo.Identity = { DeviceInfo.current() }
    ) {
        self.deviceInfo = deviceInfo
        if let profile = initialProfile {
            self.emoji = profile.emoji
            self.name = profile.name
            self.source = .custom
        } else {
            let info = deviceInfo()
            self.emoji = info.emoji
            self.name = info.name
            self.source = .device
        }
        self.onProceed = onProceed
    }

    var canProceed: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// True when the current identity already equals the device's own identity,
    /// so offering a "Device Info" shortcut would be a no-op. Drives whether the
    /// button is shown — including when returning from SearchView with a profile
    /// that happens to match the device (where `source` is `.custom`).
    var matchesDeviceInfo: Bool {
        let info = deviceInfo()
        return emoji == info.emoji
            && name.trimmingCharacters(in: .whitespaces) == info.name.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Transitions

    func randomize() {
        let id = NameGenerator.generate()
        emoji = id.emoji
        name = id.name
        source = .random
    }

    func useDeviceInfo() {
        let info = deviceInfo()
        emoji = info.emoji
        name = info.name
        source = .device
    }

    // Called via a custom Binding — bypasses programmatic changes.
    func nameEditedByUser(to value: String) {
        name = value
        source = .custom
    }

    // Called via a custom Binding from the emoji picker.
    func emojiSelectedByUser(_ value: String) {
        emoji = value
        source = .custom
    }

    // Pure function — nonisolated so it can be called from UIKit delegate callbacks.
    nonisolated static func isValidEmoji(_ string: String) -> Bool {
        guard !string.isEmpty,
              let first = string.unicodeScalars.first else { return false }
        // Accept scalars that render as emoji by default, or multi-scalar sequences
        // (ZWJ families, keycaps with variation selectors, flags, etc.).
        // Excludes bare digits/punctuation that have an emoji property but no presentation.
        return first.properties.isEmojiPresentation ||
               (first.properties.isEmoji && string.unicodeScalars.count > 1)
    }

    func proceed() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onProceed(emoji, trimmed)
    }
}
