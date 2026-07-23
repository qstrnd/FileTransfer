import UIKit

/// Unobtrusive pill telling the user that transfer history is turned off and
/// how to re-enable it. Reused in two places (see `HistoryDisabledBannerSupplementary`):
/// as the curtain's empty-state message, and as the first element above the
/// list when history is off but older entries still exist.
final class HistoryDisabledBannerPill: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        let icon = UIImageView(image: UIImage(systemName: "clock.badge.xmark"))
        icon.tintColor = .secondaryLabel
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = "Transfer history is off. Turn it back on from the ⋯ menu to save new transfers."
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let pill = UIView()
        pill.backgroundColor = .secondarySystemFill
        pill.layer.cornerRadius = 12
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(stack)
        addSubview(pill)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),

            stack.topAnchor.constraint(equalTo: pill.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -14),

            pill.topAnchor.constraint(equalTo: topAnchor),
            pill.bottomAnchor.constraint(equalTo: bottomAnchor),
            pill.leadingAnchor.constraint(equalTo: leadingAnchor),
            pill.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
}

/// Collection-view boundary supplementary that hosts a `HistoryDisabledBannerPill`,
/// used as a global header so the banner is the first element above the history list.
final class HistoryDisabledBannerSupplementary: UICollectionReusableView {
    static let elementKind = "HistoryDisabledBanner"

    private let pill = HistoryDisabledBannerPill()

    override init(frame: CGRect) {
        super.init(frame: frame)
        pill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pill)
        NSLayoutConstraint.activate([
            pill.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            pill.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            pill.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            pill.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}
