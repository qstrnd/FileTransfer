import UIKit

/// UIKit palette for each transfer type.
/// Referenced by both `TransferActionButton` (icon tile) and `TransferHistoryCell` (badge).
extension TransferType {
    var normalBG: UIColor {
        switch self {
        case .text:     UIColor(red: 0.906, green: 0.969, blue: 0.941, alpha: 1) // #E7F7F0 green
        case .photo:    UIColor(red: 1.000, green: 0.929, blue: 0.949, alpha: 1) // #FFEDEB
        case .document: UIColor(red: 0.918, green: 0.953, blue: 1.000, alpha: 1) // #EAF3FF blue
        case .contact:  UIColor(red: 1.000, green: 0.961, blue: 0.878, alpha: 1) // #FFF5E0
        }
    }

    var pressedBG: UIColor {
        switch self {
        case .text:     UIColor(red: 0.804, green: 0.941, blue: 0.878, alpha: 1) // #CDF0E0 green
        case .photo:    UIColor(red: 1.000, green: 0.847, blue: 0.878, alpha: 1) // #FFD8E0
        case .document: UIColor(red: 0.843, green: 0.914, blue: 1.000, alpha: 1) // #D7E9FF blue
        case .contact:  UIColor(red: 1.000, green: 0.929, blue: 0.773, alpha: 1) // #FFEDD5
        }
    }

    var tintColor: UIColor {
        switch self {
        case .text:     .systemGreen
        case .photo:    .systemPink
        case .document: .systemBlue
        case .contact:  .systemOrange
        }
    }
}
