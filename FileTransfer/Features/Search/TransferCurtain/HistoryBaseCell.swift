import UIKit

/// Shared scaffold for all history cells.
/// Lays out: avatar (top-left) | content area (centre) | badge + time (top-right).
/// Subclasses add their content views between `contentLeading` and `contentTrailing`,
/// pinned below `contentTop` and above `contentBottom`.
class HistoryBaseCell: UICollectionViewCell {

    // MARK: - Shared views

    let avatarContainer: UIView = {
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

    let statusBadge: HistoryStatusBadge = {
        let b = HistoryStatusBadge()
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    let timeLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12)
        l.textColor = .secondaryLabel
        l.textAlignment = .right
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.setContentCompressionResistancePriority(.required, for: .horizontal)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    let separator: UIView = {
        let v = UIView()
        v.backgroundColor = .separator
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Content-area anchors for subclasses

    var contentLeading: NSLayoutXAxisAnchor { avatarContainer.trailingAnchor }
    var contentTrailing: NSLayoutXAxisAnchor { statusBadge.leadingAnchor }
    var contentTop: NSLayoutYAxisAnchor { avatarContainer.topAnchor }
    var contentBottom: NSLayoutYAxisAnchor { separator.topAnchor }
    let contentInsetLeading: CGFloat = 12
    let contentInsetTrailing: CGFloat = -8

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBase()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Configure

    func configure(with record: TransferRecord) {
        avatarLabel.text = record.peerEmoji
        statusBadge.configure(direction: record.direction)
        timeLabel.text = record.date.formatted(.relative(presentation: .named))
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarLabel.text = nil
        timeLabel.text = nil
    }

    // MARK: - Base layout

    private func setupBase() {
        avatarContainer.addSubview(avatarLabel)
        contentView.addSubview(avatarContainer)
        contentView.addSubview(statusBadge)
        contentView.addSubview(timeLabel)
        contentView.addSubview(separator)

        NSLayoutConstraint.activate([
            // Avatar: 44 × 44, top-leading
            avatarContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            avatarContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarContainer.widthAnchor.constraint(equalToConstant: 44),
            avatarContainer.heightAnchor.constraint(equalToConstant: 44),

            avatarLabel.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor),

            // Badge: top-trailing
            statusBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            statusBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            // Time: below badge, trailing-aligned
            timeLabel.topAnchor.constraint(equalTo: statusBadge.bottomAnchor, constant: 4),
            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            // Separator: hairline at bottom
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }
}
