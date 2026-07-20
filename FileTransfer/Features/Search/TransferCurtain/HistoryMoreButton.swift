import UIKit

/// Small circular "⋯ more" overflow button for a history cell: a solid blue
/// disc with the ellipsis punched out in the curtain background colour.
///
/// Its touch area is inflated beyond the visible circle so the small control
/// stays easy to hit.
final class HistoryMoreButton: UIButton {

    private static let diameter: CGFloat = 24
    /// Extra tappable margin around the visible circle, on every side.
    private static let hitInset: CGFloat = 12

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        backgroundColor = .tertiarySystemFill
        layer.cornerRadius = Self.diameter / 2
        clipsToBounds = true

        // Dynamic colours adapt to light/dark on their own (UIColor, not CGColor).
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        setImage(UIImage(systemName: "ellipsis", withConfiguration: config), for: .normal)
        tintColor = .secondaryLabel

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.diameter),
            heightAnchor.constraint(equalToConstant: Self.diameter),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    // Enlarge the hit area beyond the visible bounds so the small circle stays
    // comfortable to tap.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -Self.hitInset, dy: -Self.hitInset).contains(point)
    }
}
