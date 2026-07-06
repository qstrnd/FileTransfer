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
        let color = UIColor.transferCurtainBackground.resolvedColor(with: traitCollection).cgColor
        // Each avatarContainer subview is a shadow-casting wrapper; the actual
        // bordered circle is its one subview.
        avatarContainer.subviews.forEach { $0.subviews.first?.layer.borderColor = color }
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
            // Front bubble (bottom-right, larger) is primary and fully visible;
            // back bubble (top-left, smaller) is secondary, sits behind it in
            // z-order, and is nudged a bit further down so it tucks in under it.
            let slots: [Slot] = [(36, 8, 8), (28, 0, 4)]
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
        makeAvatarCircle(text: peer.emojiComponent, size: size, fontSize: size * 0.52, textColor: .label)
    }

    private func makeCountCircle(count: Int, size: CGFloat) -> UIView {
        makeAvatarCircle(text: "+\(count)", size: size, fontSize: size * 0.38, textColor: .secondaryLabel, weight: .semibold)
    }

    private func makeAvatarCircle(
        text: String, size: CGFloat, fontSize: CGFloat, textColor: UIColor, weight: UIFont.Weight = .regular
    ) -> UIView {
        // Outer wrapper casts the shadow; inner `circle` clips content to the
        // round shape — clipsToBounds and shadows can't coexist on one layer.
        // Same "elevated card" treatment as Search's hero/peer bubbles
        // (SearchHeroSection, PeerCell) and Onboarding's identity circle.
        let wrapper = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        wrapper.layer.shadowColor = UIColor.black.cgColor
        wrapper.layer.shadowOpacity = 0.15
        wrapper.layer.shadowRadius = 3
        wrapper.layer.shadowOffset = CGSize(width: 0, height: 1)

        let circle = UIView(frame: wrapper.bounds)
        circle.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        circle.backgroundColor = .historyAvatarBubbleFill
        circle.layer.borderWidth = 1.5
        // Resolve against this cell's own trait collection now — a plain
        // `.cgColor` grab on a dynamic UIColor snapshots whatever its default,
        // unresolved appearance is, which won't reliably match the cell's
        // actual current background on every fresh configure/reuse.
        circle.layer.borderColor = UIColor.transferCurtainBackground
            .resolvedColor(with: traitCollection).cgColor
        circle.layer.cornerRadius = size / 2
        circle.clipsToBounds = true
        wrapper.addSubview(circle)

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: fontSize, weight: weight)
        label.textColor = textColor
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        circle.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: circle.topAnchor),
            label.bottomAnchor.constraint(equalTo: circle.bottomAnchor),
            label.leadingAnchor.constraint(equalTo: circle.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: circle.trailingAnchor),
        ])

        return wrapper
    }
}
