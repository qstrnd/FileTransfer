import UIKit

extension UIColor {
    /// TransferCurtain's own background: primary (`.systemBackground`) in
    /// light mode, secondary (`.secondarySystemBackground`) in dark mode, so
    /// the sheet reads as an elevated surface over the darker page behind it
    /// instead of blending into a near-black scrim. Also used as the
    /// cutout/border color anywhere a view needs to blend into the curtain's
    /// background (avatar borders, badge borders, edge gradients on scroll strips).
    static var transferCurtainBackground: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? .secondarySystemBackground : .systemBackground
        }
    }

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

    /// Fill for history-row avatar bubbles — fixed literals, not semantic
    /// system colors. Matching Search's `.secondarySystemGroupedBackground`
    /// bubble color exactly would resolve to `rgb(28,28,30)` in dark mode,
    /// identical to `transferCurtainBackground` itself, which made a
    /// single-peer bubble invisible against the curtain specifically (even
    /// though it contrasts fine against Search's much-darker page
    /// background) — these literals sidestep that collision.
    static var historyAvatarBubbleFill: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 44/255, green: 44/255, blue: 48/255, alpha: 1)
                : UIColor(red: 244/255, green: 244/255, blue: 245/255, alpha: 1)
        }
    }
}
