import UIKit

extension UIColor {
    /// TransferCurtain's own background — same token SearchView.swift uses for
    /// its page background (`Color(.systemGroupedBackground)`), so the sheet
    /// reads as part of the same surface rather than a mismatched white/black
    /// card floating over it. Also used as the cutout/border color anywhere a
    /// view needs to blend into the curtain's background (avatar borders,
    /// badge borders, edge gradients on scroll strips).
    static var transferCurtainBackground: UIColor { .systemGroupedBackground }

    /// Subtle darkening veil for white/light content (peer-avatar bubbles,
    /// photo thumbnails, document cards) in history rows. Fully transparent
    /// (passthrough) in light mode; a light black wash in dark mode so bright
    /// content doesn't look glaringly out of place against the darker curtain
    /// background.
    static var curtainDarkModeVeil: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor.black.withAlphaComponent(0.16) : .clear
        }
    }
}
