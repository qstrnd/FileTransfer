import UIKit

/// UIKit palette for each transfer type.
/// Referenced by both `TransferActionButton` (icon tile) and `TransferHistoryCell` (badge).
extension TransferType {
    var normalBG: UIColor {
        switch self {
        case .text:     .transferTypeGreenNormalBG
        case .photo:    .transferTypePinkNormalBG
        case .document: .transferTypeBlueNormalBG
        case .contact:  .transferTypeOrangeNormalBG
        case .file:     .transferTypeBlueNormalBG
        }
    }

    var pressedBG: UIColor {
        switch self {
        case .text:     .transferTypeGreenPressedBG
        case .photo:    .transferTypePinkPressedBG
        case .document: .transferTypeBluePressedBG
        case .contact:  .transferTypeOrangePressedBG
        case .file:     .transferTypeBluePressedBG
        }
    }

    var tintColor: UIColor {
        switch self {
        case .text:     .systemGreen
        case .photo:    .systemPink
        case .document: .systemBlue
        case .contact:  .systemOrange
        case .file:     .systemBlue
        }
    }
}

// MARK: - Palette

// Light values are pale washes (~95% lightness); dark values follow the same
// hue but invert to a deep, muted wash (~15-20% lightness) instead of staying
// pale — the same light/dark relationship Apple's own system colors use, just
// applied to a tinted background instead of a foreground tint.
private extension UIColor {
    static var transferTypeGreenNormalBG: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.106, green: 0.224, blue: 0.161, alpha: 1) // #1B392A
                : UIColor(red: 0.906, green: 0.969, blue: 0.941, alpha: 1) // #E7F7F0
        }
    }
    static var transferTypeGreenPressedBG: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.137, green: 0.294, blue: 0.212, alpha: 1) // #234B36
                : UIColor(red: 0.804, green: 0.941, blue: 0.878, alpha: 1) // #CDF0E0
        }
    }

    static var transferTypePinkNormalBG: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.239, green: 0.125, blue: 0.125, alpha: 1) // #3D2020
                : UIColor(red: 1.000, green: 0.929, blue: 0.949, alpha: 1) // #FFEDEB
        }
    }
    static var transferTypePinkPressedBG: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.302, green: 0.149, blue: 0.149, alpha: 1) // #4D2626
                : UIColor(red: 1.000, green: 0.847, blue: 0.878, alpha: 1) // #FFD8E0
        }
    }

    static var transferTypeBlueNormalBG: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.110, green: 0.173, blue: 0.259, alpha: 1) // #1C2C42
                : UIColor(red: 0.918, green: 0.953, blue: 1.000, alpha: 1) // #EAF3FF
        }
    }
    static var transferTypeBluePressedBG: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.141, green: 0.216, blue: 0.310, alpha: 1) // #24374F
                : UIColor(red: 0.843, green: 0.914, blue: 1.000, alpha: 1) // #D7E9FF
        }
    }

    static var transferTypeOrangeNormalBG: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.239, green: 0.188, blue: 0.086, alpha: 1) // #3D3016
                : UIColor(red: 1.000, green: 0.961, blue: 0.878, alpha: 1) // #FFF5E0
        }
    }
    static var transferTypeOrangePressedBG: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.290, green: 0.231, blue: 0.110, alpha: 1) // #4A3B1C
                : UIColor(red: 1.000, green: 0.929, blue: 0.773, alpha: 1) // #FFEDD5
        }
    }
}

// MARK: - History status badge palette

/// Colors for `HistoryStatusBadge`'s "Received"/"Sent" pill — keyed by
/// `TransferDirection`, not `TransferType`, so kept separate from the palette above.
extension UIColor {
    static var historyReceivedTint: UIColor { .systemGreen }

    static var historyReceivedBG: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.106, green: 0.224, blue: 0.161, alpha: 1) // #1B392A
                : UIColor(red: 0.840, green: 0.960, blue: 0.870, alpha: 1) // #D6F5DE
        }
    }

    static var historySentTint: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.349, green: 0.616, blue: 1.000, alpha: 1) // #599DFF
                : UIColor(red: 0.200, green: 0.480, blue: 1.000, alpha: 1) // #337AFF
        }
    }

    static var historySentBG: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.110, green: 0.173, blue: 0.259, alpha: 1) // #1C2C42
                : UIColor(red: 0.870, green: 0.930, blue: 1.000, alpha: 1) // #DEEDFF
        }
    }
}
