import UIKit

/// Circular "⋯ more" overflow button that floats over a history cell's media.
///
/// Styled like `HistoryStatusBadge`: a neutral fill ringed with a 1.5pt stroke
/// in the curtain background colour, so it separates cleanly from the image
/// beneath it. Its touch area is inflated beyond the visible circle so it stays
/// easy to hit without crowding the artwork.
final class HistoryMoreButton: UIButton {

    private static let diameter: CGFloat = 30
    /// Extra tappable margin around the visible circle, on every side.
    private static let hitInset: CGFloat = 12

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        backgroundColor = .secondarySystemFill
        layer.cornerRadius = Self.diameter / 2
        layer.borderWidth = 1.5
        layer.borderColor = UIColor.transferCurtainBackground.cgColor
        clipsToBounds = true

        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        setImage(UIImage(systemName: "ellipsis", withConfiguration: config), for: .normal)
        tintColor = .label

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.diameter),
            heightAnchor.constraint(equalToConstant: Self.diameter),
        ])

        // CGColor snapshots don't re-resolve on appearance changes on their own.
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (_: HistoryMoreButton, _: UITraitCollection) in
            guard let self else { return }
            layer.borderColor = UIColor.transferCurtainBackground.resolvedColor(with: traitCollection).cgColor
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func appWillEnterForeground() {
        layer.borderColor = UIColor.transferCurtainBackground.resolvedColor(with: traitCollection).cgColor
    }

    // Enlarge the hit area beyond the visible bounds so the small circle stays
    // comfortable to tap.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -Self.hitInset, dy: -Self.hitInset).contains(point)
    }
}
