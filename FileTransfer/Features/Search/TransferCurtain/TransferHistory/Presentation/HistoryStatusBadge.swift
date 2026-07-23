import UIKit

/// Pill-shaped badge showing transfer direction.
/// Green "↓ Received" or blue "↑ Sent", matching the mockup.
final class HistoryStatusBadge: UIView {

    private let iconView = UIImageView()
    private let textLabel = UILabel()
    private var contentStack: UIStackView!

    override var intrinsicContentSize: CGSize {
        let s = contentStack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return CGSize(width: s.width + 18, height: s.height + 10)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(direction: TransferDirection) {
        let received = direction == .received
        let tint: UIColor = received ? .historyReceivedTint : .historySentTint
        backgroundColor = received ? .historyReceivedBG : .historySentBG
        // Diagonal call-direction arrows, matching the Phone app's recents list.
        let iconName = received ? "arrow.down.left" : "arrow.up.right"
        iconView.image = UIImage(systemName: iconName,
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold))
        iconView.tintColor = tint
        textLabel.text = received ? "Received" : "Sent"
        textLabel.textColor = tint
        invalidateIntrinsicContentSize()
    }

    private func refreshBorderColor(for tc: UITraitCollection) {
        layer.borderColor = UIColor.transferCurtainBackground.resolvedColor(with: tc).cgColor
    }

    @objc private func appWillEnterForeground() { refreshBorderColor(for: traitCollection) }

    private func setup() {
        layer.cornerRadius = 12
        layer.borderWidth = 1.5
        layer.borderColor = UIColor.transferCurtainBackground.cgColor
        clipsToBounds = true

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (_: HistoryStatusBadge, _: UITraitCollection) in
            // The handler's second parameter is the *previous* trait collection,
            // not the new one — read self.traitCollection, already updated by now.
            guard let self else { return }
            refreshBorderColor(for: traitCollection)
        }
        NotificationCenter.default.addObserver(self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil)

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        textLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        textLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [iconView, textLabel])
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        contentStack = stack

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 13),
            iconView.heightAnchor.constraint(equalToConstant: 13),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
        ])
    }
}
