import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red:   CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >>  8) & 0xFF) / 255,
            blue:  CGFloat( hex        & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum ContactColor: Int, Codable, CaseIterable, Sendable {
    case red = 0, purple, orange, yellow, tomato, skyBlue, blue, green

    var uiColor: UIColor {
        switch self {
        case .red:     return UIColor(hex: 0xFF2D55)
        case .purple:  return UIColor(hex: 0x5856D6)
        case .orange:  return UIColor(hex: 0xFF9500)
        case .yellow:  return UIColor(hex: 0xFFCC00)
        case .tomato:  return UIColor(hex: 0xFF3B30)
        case .skyBlue: return UIColor(hex: 0x5AC8FA)
        case .blue:    return UIColor(hex: 0x007AFF)
        case .green:   return UIColor(hex: 0x4CD964)
        }
    }

    var swiftUIColor: Color { Color(uiColor: uiColor) }
    var backgroundUIColor: UIColor { uiColor.withAlphaComponent(0.15) }
    var backgroundSwiftUIColor: Color { swiftUIColor.opacity(0.15) }

    // DJB2 over UTF-8 bytes — stable across devices and process restarts.
    static func assigned(for name: String) -> ContactColor {
        let hash = name.utf8.reduce(5381) { ($0 &* 31) &+ $0 &+ Int($1) }
        return allCases[abs(hash) % allCases.count]
    }
}
