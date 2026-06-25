import UIKit

/// Base history cell. Always shows: emoji avatar with a type-coloured direction badge,
/// peer name, transfer detail, and relative timestamp.
///
/// Future configurations can add preview content (image thumbnail, document icon)
/// below the base row by inserting views between detailLabel and the separator.
final class TransferHistoryCell: UICollectionViewCell {
    static let reuseID = "TransferHistoryCell"

    // MARK: - Subviews

    private let avatarContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .systemGroupedBackground
        v.layer.cornerRadius = 22
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let avatarLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 24)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let badgeContainer: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 10
        v.layer.borderWidth = 2
        v.layer.borderColor = UIColor.systemBackground.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let badgeIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .semibold)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let detailLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let timeLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12)
        l.textColor = .secondaryLabel
        l.textAlignment = .right
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.setContentCompressionResistancePriority(.required, for: .horizontal)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let separator: UIView = {
        let v = UIView()
        v.backgroundColor = .separator
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (_: TransferHistoryCell, _) in
            self?.badgeContainer.layer.borderColor = UIColor.systemBackground.cgColor
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Configure

    func configure(with record: TransferRecord) {
        avatarLabel.text = record.peerEmoji
        nameLabel.text = record.peerName
        detailLabel.text = record.detail ?? record.type.defaultDetail
        timeLabel.text = record.date.formatted(.relative(presentation: .named))

        // Badge colour = transfer type; arrow direction = sent vs received.
        // arrow.down.left = incoming (received from peer)
        // arrow.up.right  = outgoing (sent to peer)
        let arrow = record.direction == .received ? "arrow.down.left" : "arrow.up.right"
        badgeContainer.backgroundColor = record.type.normalBG
        badgeIcon.image = UIImage(
            systemName: arrow,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 9, weight: .bold)
        )
        badgeIcon.tintColor = record.type.tintColor
    }

    // MARK: - Setup

    private func setupViews() {
        avatarContainer.addSubview(avatarLabel)
        badgeContainer.addSubview(badgeIcon)

        contentView.addSubview(avatarContainer)
        contentView.addSubview(badgeContainer)
        contentView.addSubview(nameLabel)
        contentView.addSubview(detailLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(separator)

        let minHeight = contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 68)
        minHeight.priority = .required

        NSLayoutConstraint.activate([
            minHeight,

            // Avatar: 44×44, 20pt from leading, vertically centred
            avatarContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            avatarContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarContainer.widthAnchor.constraint(equalToConstant: 44),
            avatarContainer.heightAnchor.constraint(equalToConstant: 44),

            avatarLabel.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor),

            // Badge: 20×20, bottom-trailing corner of avatar
            badgeContainer.widthAnchor.constraint(equalToConstant: 20),
            badgeContainer.heightAnchor.constraint(equalToConstant: 20),
            badgeContainer.centerXAnchor.constraint(equalTo: avatarContainer.trailingAnchor, constant: -2),
            badgeContainer.centerYAnchor.constraint(equalTo: avatarContainer.bottomAnchor, constant: -2),

            badgeIcon.centerXAnchor.constraint(equalTo: badgeContainer.centerXAnchor),
            badgeIcon.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor),
            badgeIcon.widthAnchor.constraint(equalToConstant: 12),
            badgeIcon.heightAnchor.constraint(equalToConstant: 12),

            // Time: trailing 20pt, vertically aligned with name
            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            timeLabel.firstBaselineAnchor.constraint(equalTo: nameLabel.firstBaselineAnchor),

            // Name: after avatar, bounded by time label
            nameLabel.leadingAnchor.constraint(equalTo: avatarContainer.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),

            // Detail: below name
            // Future preview content can be inserted between detailLabel and the separator.
            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),
            detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -14),

            // Separator: hairline at bottom, inset to match leading text
            separator.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }
}
