import UIKit

/// Base cell for all history rows.
/// Three-column layout: avatar (left 44×44) | content (centre) | badge+time (right, fixed 90pt wide).
/// Subclasses add their content views to `contentContainer`.
class HistoryBaseCell: UICollectionViewCell {

    // MARK: - Header views (rendered above content in Z-order)

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

    private let timeLabelPill: UIView = {
        let v = UIView()
        // Matches cell background — only visible when content (image/doc) appears beneath it.
        v.backgroundColor = .systemBackground
        v.layer.cornerRadius = 7
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    let timeLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11)
        l.textColor = .secondaryLabel
        l.textAlignment = .right
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.setContentCompressionResistancePriority(.required, for: .horizontal)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Content area for subclasses

    /// Sits between the avatar and the right badge column.
    /// Subclasses add their views here pinned to this container's edges.
    let contentContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Separator

    let separator: UIView = {
        let v = UIView()
        v.backgroundColor = .separator
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

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
        // contentContainer added first → sits behind header elements in Z-order
        contentView.addSubview(contentContainer)
        contentView.addSubview(separator)

        // Fixed-width right column that holds badge + timestamp.
        // Added after content → rendered on top.
        let rightColumn = UIView()
        rightColumn.translatesAutoresizingMaskIntoConstraints = false
        timeLabelPill.addSubview(timeLabel)
        rightColumn.addSubview(statusBadge)
        rightColumn.addSubview(timeLabelPill)

        avatarContainer.addSubview(avatarLabel)
        contentView.addSubview(avatarContainer)
        contentView.addSubview(rightColumn)

        NSLayoutConstraint.activate([
            // Avatar: 44×44, top-left
            avatarContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            avatarContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarContainer.widthAnchor.constraint(equalToConstant: 44),
            avatarContainer.heightAnchor.constraint(equalToConstant: 44),
            avatarLabel.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor),

            // Right column: fixed 90pt wide, spans full cell height, pinned to trailing edge
            rightColumn.topAnchor.constraint(equalTo: contentView.topAnchor),
            rightColumn.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            rightColumn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            rightColumn.widthAnchor.constraint(equalToConstant: 90),

            // Badge: top of right column, trailing-aligned (natural width via intrinsicContentSize)
            statusBadge.topAnchor.constraint(equalTo: rightColumn.topAnchor, constant: 14),
            statusBadge.trailingAnchor.constraint(equalTo: rightColumn.trailingAnchor),

            // Timestamp pill: below badge, trailing-aligned
            timeLabelPill.topAnchor.constraint(equalTo: statusBadge.bottomAnchor, constant: 4),
            timeLabelPill.trailingAnchor.constraint(equalTo: rightColumn.trailingAnchor),

            // Time label insets inside pill
            timeLabel.topAnchor.constraint(equalTo: timeLabelPill.topAnchor, constant: 2),
            timeLabel.bottomAnchor.constraint(equalTo: timeLabelPill.bottomAnchor, constant: -2),
            timeLabel.leadingAnchor.constraint(equalTo: timeLabelPill.leadingAnchor, constant: 5),
            timeLabel.trailingAnchor.constraint(equalTo: timeLabelPill.trailingAnchor, constant: -5),

            // Content container: between avatar.trailing and rightColumn.leading
            contentContainer.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: avatarContainer.trailingAnchor, constant: 12),
            contentContainer.trailingAnchor.constraint(equalTo: rightColumn.leadingAnchor, constant: -8),
            contentContainer.bottomAnchor.constraint(equalTo: separator.topAnchor),

            // Separator: hairline at cell bottom
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
        ])

        // Ensure the cell is always tall enough to show the full avatar.
        contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 72).isActive = true
    }
}
