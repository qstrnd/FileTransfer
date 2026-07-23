import UIKit

/// UIKit-backed haptic feedback. Each call creates a fresh generator since
/// these are infrequent, unpredictable events (a tap, an arrival, a failure)
/// rather than a rapid-fire sequence that would benefit from a shared,
/// pre-`prepare()`d instance.
@MainActor
final class HapticFeedbackService: HapticsGate {
    static let shared = HapticFeedbackService()

    private init() {}

    func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
