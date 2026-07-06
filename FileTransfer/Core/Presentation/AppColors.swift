import SwiftUI

/// Shared SwiftUI color tokens used by 2+ features. Feature-specific colors
/// belong in that feature's own Presentation folder instead (see
/// `TransferTypeColors.swift`, `TransferCurtainColors.swift`).
extension Color {
    /// Fill for the hero/peer avatar bubbles (Onboarding's identity circle,
    /// Search's hero and peer-grid circles) — the standard "card on grouped
    /// page" pairing (`.secondarySystemGroupedBackground`) so these read as a
    /// light card in light mode and a dark elevated card in dark mode,
    /// instead of a hardcoded white that stays stark white against a
    /// near-black dark-mode background.
    ///
    /// TransferCurtain's history-row avatars use their own
    /// `UIColor.historyAvatarBubbleFill` instead (see `TransferCurtainColors.swift`)
    /// since this token's dark value collapses into the curtain's own
    /// background there.
    static var avatarBubbleBackground: Color { Color(.secondarySystemGroupedBackground) }
}
