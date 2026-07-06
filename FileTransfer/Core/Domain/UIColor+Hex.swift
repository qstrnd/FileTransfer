import UIKit

extension UIColor {
    /// Hex string of this color's RGBA components (e.g. "#1C1C1EFF"). Call this
    /// on an already-resolved color (e.g. via `resolvedColor(with:)`) — dynamic
    /// colors report whatever their unresolved/default appearance is. Handy for
    /// logging color resolution while debugging light/dark mode issues.
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "#%02X%02X%02X%02X",
            Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)), Int(round(a * 255))
        )
    }
}
