import UIKit

/// Base cell for all history rows.
/// Three-column layout: avatar cluster (left 44×44) | content (centre) | badge+time (right, fixed 90pt wide).
/// Subclasses add their content views to `contentContainer`.
class HistoryBaseCell: UICollectionViewCell {

    // MARK: - Header views (rendered above content in Z-order)

    /// 44×44 cluster of overlapping peer-emoji circles.
    let avatarContainer = HistoryPeerBubbleClusterView()

    let statusBadge: HistoryStatusBadge = {
        let b = HistoryStatusBadge()
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let timeLabelPill: UIView = {
        let v = UIView()
        // Matches cell background — only visible when content (image/doc) appears beneath it.
        v.backgroundColor = .transferCurtainBackground
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

    /// ⋯ overflow button at the cell's bottom-right corner. Owned and positioned
    /// here so its placement is defined once; individual cells opt in by
    /// overriding `shouldDisplayMoreButton()`. The data source attaches its menu.
    /// (Named `overflowButton` to avoid colliding with `HistoryTextCell`'s own
    /// "more" text-expand button.)
    let overflowButton = HistoryMoreButton()

    /// Whether this cell shows the ⋯ more-button. Off by default; media/document
    /// cells override to return `true`.
    func shouldDisplayMoreButton() -> Bool { false }

    // MARK: - Content area for subclasses

    /// Sits between the avatar cluster and the right badge column.
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
        avatarContainer.configure(peers: record.peers)
        statusBadge.configure(direction: record.direction)
        timeLabel.text = record.date.formatted(.relative(presentation: .named))
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarContainer.reset()
        timeLabel.text = nil
        overflowButton.menu = nil
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

        contentView.addSubview(avatarContainer)
        contentView.addSubview(rightColumn)
        // Added last so it draws above the content; hidden unless the subclass opts in.
        contentView.addSubview(overflowButton)
        overflowButton.isHidden = !shouldDisplayMoreButton()

        NSLayoutConstraint.activate([
            // Avatar cluster: 44×44, top-left
            avatarContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            avatarContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarContainer.widthAnchor.constraint(equalToConstant: 44),
            avatarContainer.heightAnchor.constraint(equalToConstant: 44),

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

            // Overflow button: trailing edge, in the meta row below the content
            // (subclasses leave a gap between their content and the meta label so
            // the button never overlaps the image/document).
            overflowButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            overflowButton.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -6),
        ])

        // Ensure the cell is always tall enough to show the full avatar cluster.
        contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 72).isActive = true
    }
}
