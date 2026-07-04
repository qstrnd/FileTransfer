import UIKit

/// Base cell for all history rows.
/// Three-column layout: avatar cluster (left 44×44) | content (centre) | badge+time (right, fixed 90pt wide).
/// Subclasses add their content views to `contentContainer`.
class HistoryBaseCell: UICollectionViewCell {

    // MARK: - Header views (rendered above content in Z-order)

    /// 44×44 container. Filled with 1–3 overlapping peer-emoji circles by `configurePeerCluster`.
    let avatarContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
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
        configurePeerCluster(peers: record.peers)
        statusBadge.configure(direction: record.direction)
        timeLabel.text = record.date.formatted(.relative(presentation: .named))
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarContainer.subviews.forEach { $0.removeFromSuperview() }
        timeLabel.text = nil
    }

    // MARK: - Base layout

    private func setupBase() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (_: HistoryBaseCell, _: UITraitCollection) in
            guard let self else { return }
            refreshAvatarBorderColors()
        }
        NotificationCenter.default.addObserver(self,
            selector: #selector(refreshAvatarBorderColors),
            name: UIApplication.willEnterForegroundNotification,
            object: nil)
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
        ])

        // Ensure the cell is always tall enough to show the full avatar cluster.
        contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 72).isActive = true
    }

    @objc private func refreshAvatarBorderColors() {
        let color = UIColor.systemBackground.resolvedColor(with: traitCollection).cgColor
        avatarContainer.subviews.forEach { $0.layer.borderColor = color }
    }

    // MARK: - Peer avatar cluster

    private typealias Slot = (size: CGFloat, x: CGFloat, y: CGFloat)

    // Triangle slots (all fit within the 44×44 avatarContainer):
    //   [0] primary   — top-center  30×30 @ (7, 0)
    //   [1] secondary — bottom-left 26×26 @ (0, 18)
    //   [2] tertiary  — bottom-right 26×26 @ (18, 18)
    private static let triangleSlots: [Slot] = [
        (30, 7,  0),
        (26, 0,  18),
        (26, 18, 18),
    ]

    private func configurePeerCluster(peers: [Peer]) {
        avatarContainer.subviews.forEach { $0.removeFromSuperview() }
        guard !peers.isEmpty else { return }

        let total = peers.count

        switch total {
        case 1:
            addCircle(makePeerCircle(peer: peers[0], size: 44), slot: (44, 0, 0))

        case 2:
            // Primary top-left, secondary bottom-right — add back-to-front.
            let slots: [Slot] = [(36, 0, 0), (28, 16, 16)]
            for (peer, slot) in zip(peers, slots).reversed() {
                addCircle(makePeerCircle(peer: peer, size: slot.size), slot: slot)
            }

        case 3:
            // Triangle — add back-to-front so primary lands on top.
            for (peer, slot) in zip(peers, Self.triangleSlots).reversed() {
                addCircle(makePeerCircle(peer: peer, size: slot.size), slot: slot)
            }

        default:
            // Show first 2 peers in the top-two triangle slots + "+N" count badge at bottom-right.
            let visible = Array(peers.prefix(2))
            let remaining = total - 2
            // Count badge goes in first (lowest Z), peer circles added on top.
            addCircle(makeCountCircle(count: remaining, size: Self.triangleSlots[2].size),
                      slot: Self.triangleSlots[2])
            for (peer, slot) in zip(visible, Self.triangleSlots).reversed() {
                addCircle(makePeerCircle(peer: peer, size: slot.size), slot: slot)
            }
        }
    }

    private func addCircle(_ view: UIView, slot: Slot) {
        view.frame = CGRect(x: slot.x, y: slot.y, width: slot.size, height: slot.size)
        view.layer.cornerRadius = slot.size / 2
        avatarContainer.addSubview(view)
    }

    private func makePeerCircle(peer: Peer, size: CGFloat) -> UIView {
        makeAvatarCircle(text: peer.emojiComponent, fontSize: size * 0.52, textColor: .label)
    }

    private func makeCountCircle(count: Int, size: CGFloat) -> UIView {
        makeAvatarCircle(text: "+\(count)", fontSize: size * 0.38, textColor: .secondaryLabel, weight: .semibold)
    }

    private func makeAvatarCircle(text: String, fontSize: CGFloat, textColor: UIColor, weight: UIFont.Weight = .regular) -> UIView {
        let container = UIView()
        container.backgroundColor = .systemGroupedBackground
        container.layer.borderWidth = 1.5
        container.layer.borderColor = UIColor.systemBackground.cgColor

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: fontSize, weight: weight)
        label.textColor = textColor
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        return container
    }
}
