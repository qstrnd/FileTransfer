import UIKit

/// Tappable control showing a rounded-rect icon above a text label.
/// Matches the action button style from the HTML reference design.
final class TransferActionButton: UIControl {

    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    private let normalBG:  UIColor
    private let pressedBG: UIColor

    init(icon: String, title: String, normalBG: UIColor, pressedBG: UIColor, iconTint: UIColor) {
        self.normalBG  = normalBG
        self.pressedBG = pressedBG
        super.init(frame: .zero)

        iconContainer.backgroundColor = normalBG
        iconContainer.layer.cornerRadius = 16
        iconContainer.isUserInteractionEnabled = false
        iconContainer.translatesAutoresizingMaskIntoConstraints = false

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        iconView.image = UIImage(systemName: icon, withConfiguration: symbolConfig)
        iconView.tintColor = iconTint
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconView)

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.isUserInteractionEnabled = false

        let stack = UIStackView(arrangedSubviews: [iconContainer, titleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 54),
            iconContainer.heightAnchor.constraint(equalToConstant: 54),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 26),
            iconView.heightAnchor.constraint(equalToConstant: 26),

            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.iconContainer.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.92, y: 0.92)
                    : .identity
                self.iconContainer.backgroundColor = self.isHighlighted ? self.pressedBG : self.normalBG
            }
        }
    }

    override var isEnabled: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.alpha = self.isEnabled ? 1 : 0.32
            }
        }
    }
}
