import UIKit

/// 44×44 cluster of 1–3 overlapping peer-emoji circles (or a "+N" count
/// circle beyond that), used as the avatar column in `HistoryBaseCell` rows.
final class HistoryPeerBubbleClusterView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (_: HistoryPeerBubbleClusterView, _: UITraitCollection) in
            self?.refreshBorderColors()
        }
        NotificationCenter.default.addObserver(self,
            selector: #selector(refreshBorderColors),
            name: UIApplication.willEnterForegroundNotification,
            object: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Configure

    func configure(peers: [Peer]) {
        subviews.forEach { $0.removeFromSuperview() }
        guard !peers.isEmpty else { return }

        let total = peers.count

        switch total {
        case 1:
            addCircle(makePeerCircle(peer: peers[0], size: 44), slot: (44, 0, 0))

        case 2:
            // Equal-size bubbles, diagonally offset. Primary (peers[0]) sits
            // in front (bottom-right, higher z-order); secondary (peers[1])
            // sits behind it, adjusted up-left so both remain visible.
            let slots: [Slot] = [(32, 12, 12), (32, 0, 0)]
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

    /// Immediately clears the cluster ahead of the next `configure`, so reused
    /// cells don't briefly show a stale cluster while waiting to be reconfigured.
    func reset() {
        subviews.forEach { $0.removeFromSuperview() }
    }

    @objc private func refreshBorderColors() {
        let color = UIColor.transferCurtainBackground.resolvedColor(with: traitCollection).cgColor
        subviews.forEach { $0.layer.borderColor = color }
    }

    // MARK: - Slot layout

    private typealias Slot = (size: CGFloat, x: CGFloat, y: CGFloat)

    // Triangle slots (all fit within the 44×44 bounds):
    //   [0] primary   — top-center  30×30 @ (7, 0)
    //   [1] secondary — bottom-left 26×26 @ (0, 18)
    //   [2] tertiary  — bottom-right 26×26 @ (18, 18)
    private static let triangleSlots: [Slot] = [
        (30, 7,  0),
        (26, 0,  18),
        (26, 18, 18),
    ]

    private func addCircle(_ view: UIView, slot: Slot) {
        view.frame = CGRect(x: slot.x, y: slot.y, width: slot.size, height: slot.size)
        view.layer.cornerRadius = slot.size / 2
        addSubview(view)
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
        let circle = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        circle.backgroundColor = .historyAvatarBubbleFill
        circle.layer.borderWidth = 1.5
        // Resolve against this view's own trait collection now — a plain
        // `.cgColor` grab on a dynamic UIColor snapshots whatever its default,
        // unresolved appearance is, which won't reliably match the cell's
        // actual current background on every fresh configure/reuse.
        circle.layer.borderColor = UIColor.transferCurtainBackground
            .resolvedColor(with: traitCollection).cgColor
        circle.layer.cornerRadius = size / 2
        circle.clipsToBounds = true

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

        return circle
    }
}
