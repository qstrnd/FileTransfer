import UIKit

// MARK: - Avatar (photo, falling back to initials-on-color)

/// Shows the contact's actual photo when one was shared; falls back to an
/// initials-on-color circle otherwise. `photoView` and `initialsLabel` must
/// already be added to `circleView`.
private func configureAvatar(
    circleView: UIView, photoView: UIImageView, initialsLabel: UILabel, contact: ContactInfo
) {
    if let data = contact.photoData, let image = UIImage(data: data) {
        photoView.image = image
        photoView.isHidden = false
        initialsLabel.isHidden = true
        circleView.backgroundColor = .clear
    } else {
        photoView.isHidden = true
        photoView.image = nil
        initialsLabel.isHidden = false
        initialsLabel.text = contact.initials
        initialsLabel.textColor = contact.colorCode.uiColor
        circleView.backgroundColor = contact.colorCode.backgroundUIColor
    }
}

// MARK: - Card view (one contact)

private final class ContactCardView: UIView {
    let circleView = UIView()

    init(contact: ContactInfo) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        circleView.clipsToBounds = true
        circleView.translatesAutoresizingMaskIntoConstraints = false

        let photoView = UIImageView()
        photoView.contentMode = .scaleAspectFill
        photoView.translatesAutoresizingMaskIntoConstraints = false
        circleView.addSubview(photoView)

        let initialsLabel = UILabel()
        initialsLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        initialsLabel.textAlignment = .center
        initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        circleView.addSubview(initialsLabel)

        configureAvatar(circleView: circleView, photoView: photoView, initialsLabel: initialsLabel, contact: contact)

        let nameLabel = UILabel()
        nameLabel.text = contact.name
        nameLabel.font = .systemFont(ofSize: 12)
        nameLabel.textColor = .label
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(circleView)
        addSubview(nameLabel)

        NSLayoutConstraint.activate([
            circleView.topAnchor.constraint(equalTo: topAnchor),
            circleView.leadingAnchor.constraint(equalTo: leadingAnchor),
            circleView.trailingAnchor.constraint(equalTo: trailingAnchor),
            circleView.heightAnchor.constraint(equalTo: circleView.widthAnchor),

            photoView.topAnchor.constraint(equalTo: circleView.topAnchor),
            photoView.bottomAnchor.constraint(equalTo: circleView.bottomAnchor),
            photoView.leadingAnchor.constraint(equalTo: circleView.leadingAnchor),
            photoView.trailingAnchor.constraint(equalTo: circleView.trailingAnchor),

            initialsLabel.centerXAnchor.constraint(equalTo: circleView.centerXAnchor),
            initialsLabel.centerYAnchor.constraint(equalTo: circleView.centerYAnchor),

            nameLabel.topAnchor.constraint(equalTo: circleView.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            nameLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        circleView.layer.cornerRadius = circleView.bounds.width / 2
    }
}

// MARK: - Edge gradient

private final class ContactGradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
    private var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }

    init(isLeading: Bool) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        gradientLayer.startPoint = isLeading ? CGPoint(x: 0, y: 0.5) : CGPoint(x: 1, y: 0.5)
        gradientLayer.endPoint   = isLeading ? CGPoint(x: 1, y: 0.5) : CGPoint(x: 0, y: 0.5)
        gradientLayer.locations  = [0, 1]
        NotificationCenter.default.addObserver(self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateColors(for tc: UITraitCollection) {
        let bg = UIColor.transferCurtainBackground.resolvedColor(with: tc)
        gradientLayer.colors = [bg.cgColor, bg.withAlphaComponent(0).cgColor]
    }

    @objc private func appWillEnterForeground() { updateColors(for: traitCollection) }
}

// MARK: - HistoryContactCell

final class HistoryContactCell: HistoryBaseCell {


    // Match HistoryMultiItemCell insets exactly.
    private static let scrollLeftInset:   CGFloat = 72
    private static let scrollRightInset:  CGFloat = 106
    private static let edgeGradientWidth: CGFloat = 32
    private static let cardWidth:         CGFloat = 60
    private static let cardSpacing:       CGFloat = 8
    // scroll view height = card width (initials square) + gap + 2-line name label
    private static let scrollHeight:      CGFloat = cardWidth + 4 + 32

    // MARK: - Single-contact layout (inside contentContainer)

    private let singleLayout = UIView()

    private let singleCircle: UIView = {
        let v = UIView()
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let singlePhoto: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let singleInitials: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 22, weight: .semibold)
        l.textColor = .white
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let singleName: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 17, weight: .semibold)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let singlePhone: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Multi-contact scroll strip (spans full contentView width)

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.clipsToBounds = true
        sv.alwaysBounceHorizontal = true
        sv.contentInset = UIEdgeInsets(top: 0, left: 72, bottom: 0, right: 106)
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let cardStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 8
        sv.alignment = .fill
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let leftGradient  = ContactGradientView(isLeading: true)
    private let rightGradient = ContactGradientView(isLeading: false)

    private let summaryLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Constraint sets toggled between layouts.
    private var singleActiveConstraints: [NSLayoutConstraint] = []
    private var multiActiveConstraints:  [NSLayoutConstraint] = []

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayouts()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Configure

    override func configure(with record: TransferRecord) {
        super.configure(with: record)

        cardStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let contacts = record.contacts.isEmpty
            ? [ContactInfo(name: record.detail ?? "Contact", phone: nil)]
            : record.contacts

        if contacts.count == 1 {
            activateSingleLayout()
            configureSingle(contacts[0])
        } else {
            activateMultiLayout()
            configureMulti(contacts)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cardStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }

    // MARK: - Private

    private func setupLayouts() {
        // ── Single layout (in contentContainer) ──────────────────────────────
        singleLayout.translatesAutoresizingMaskIntoConstraints = false
        singleCircle.addSubview(singlePhoto)
        singleCircle.addSubview(singleInitials)
        singleLayout.addSubview(singleCircle)
        singleLayout.addSubview(singleName)
        singleLayout.addSubview(singlePhone)
        contentContainer.addSubview(singleLayout)
        contentContainer.addSubview(summaryLabel)

        let circleSize: CGFloat = 60
        singleCircle.layer.cornerRadius = circleSize / 2

        NSLayoutConstraint.activate([
            // Single layout sizing within contentContainer
            singleLayout.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 4),
            singleLayout.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            singleLayout.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),

            singleCircle.topAnchor.constraint(equalTo: singleLayout.topAnchor),
            singleCircle.leadingAnchor.constraint(equalTo: singleLayout.leadingAnchor),
            singleCircle.widthAnchor.constraint(equalToConstant: circleSize),
            singleCircle.heightAnchor.constraint(equalToConstant: circleSize),

            singlePhoto.topAnchor.constraint(equalTo: singleCircle.topAnchor),
            singlePhoto.bottomAnchor.constraint(equalTo: singleCircle.bottomAnchor),
            singlePhoto.leadingAnchor.constraint(equalTo: singleCircle.leadingAnchor),
            singlePhoto.trailingAnchor.constraint(equalTo: singleCircle.trailingAnchor),

            singleInitials.centerXAnchor.constraint(equalTo: singleCircle.centerXAnchor),
            singleInitials.centerYAnchor.constraint(equalTo: singleCircle.centerYAnchor),

            singleName.leadingAnchor.constraint(equalTo: singleCircle.trailingAnchor, constant: 10),
            singleName.trailingAnchor.constraint(equalTo: singleLayout.trailingAnchor),
            singleName.topAnchor.constraint(equalTo: singleCircle.topAnchor, constant: 6),

            singlePhone.leadingAnchor.constraint(equalTo: singleName.leadingAnchor),
            singlePhone.trailingAnchor.constraint(equalTo: singleName.trailingAnchor),
            singlePhone.topAnchor.constraint(equalTo: singleName.bottomAnchor, constant: 3),

            // Circle bottom drives singleLayout height (60pt), which propagates
            // up through contentContainer → separator → contentView to size the cell.
            singleCircle.bottomAnchor.constraint(equalTo: singleLayout.bottomAnchor),
        ])

        // Single-mode: singleLayout bottom drives contentContainer bottom
        singleActiveConstraints = [
            singleLayout.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -10),
        ]

        // ── Multi layout (scroll strip in contentView, summary in contentContainer) ──
        scrollView.addSubview(cardStack)
        contentView.insertSubview(scrollView, belowSubview: avatarContainer)
        contentView.insertSubview(leftGradient,  aboveSubview: scrollView)
        contentView.insertSubview(rightGradient, aboveSubview: leftGradient)

        let gw = Self.edgeGradientWidth
        NSLayoutConstraint.activate([
            // Scroll view: full cell width, height fixed
            scrollView.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: Self.scrollHeight),

            // Card stack inside scroll content
            cardStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            cardStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            cardStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            cardStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            cardStack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),

            // Left gradient
            leftGradient.topAnchor.constraint(equalTo: scrollView.topAnchor),
            leftGradient.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            leftGradient.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            leftGradient.widthAnchor.constraint(equalToConstant: gw),

            // Right gradient
            rightGradient.topAnchor.constraint(equalTo: scrollView.topAnchor),
            rightGradient.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            rightGradient.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rightGradient.widthAnchor.constraint(equalToConstant: gw),

            // Summary label in contentContainer, below scroll view
            summaryLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 6),
            summaryLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            summaryLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
        ])

        // Multi-mode: summaryLabel bottom drives contentContainer bottom
        multiActiveConstraints = [
            summaryLabel.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -10),
        ]

        // Gradient colors
        leftGradient.updateColors(for: traitCollection)
        rightGradient.updateColors(for: traitCollection)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (_: HistoryContactCell, _: UITraitCollection) in
            guard let self else { return }
            leftGradient.updateColors(for: traitCollection)
            rightGradient.updateColors(for: traitCollection)
        }

        // Start hidden; configure() will show the right one
        singleLayout.isHidden = true
        scrollView.isHidden = true
        leftGradient.isHidden = true
        rightGradient.isHidden = true
        summaryLabel.isHidden = true
    }

    private func activateSingleLayout() {
        NSLayoutConstraint.deactivate(multiActiveConstraints)
        NSLayoutConstraint.activate(singleActiveConstraints)
        singleLayout.isHidden = false
        scrollView.isHidden = true
        leftGradient.isHidden = true
        rightGradient.isHidden = true
        summaryLabel.isHidden = true
    }

    private func activateMultiLayout() {
        NSLayoutConstraint.deactivate(singleActiveConstraints)
        NSLayoutConstraint.activate(multiActiveConstraints)
        singleLayout.isHidden = true
        scrollView.isHidden = false
        leftGradient.isHidden = false
        rightGradient.isHidden = false
        summaryLabel.isHidden = false
    }

    private func configureSingle(_ contact: ContactInfo) {
        configureAvatar(circleView: singleCircle, photoView: singlePhoto, initialsLabel: singleInitials, contact: contact)
        singleName.text = contact.name
        singlePhone.text = contact.phone
        singlePhone.isHidden = contact.phone == nil
    }

    private func configureMulti(_ contacts: [ContactInfo]) {
        for contact in contacts {
            let card = ContactCardView(contact: contact)
            card.widthAnchor.constraint(equalToConstant: Self.cardWidth).isActive = true
            cardStack.addArrangedSubview(card)
        }
        summaryLabel.attributedText = makeSummaryText(contacts)
    }

    private func makeSummaryText(_ contacts: [ContactInfo]) -> NSAttributedString {
        let count = contacts.count
        let bold: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.label,
        ]
        let secondary: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.secondaryLabel,
        ]
        let result = NSMutableAttributedString(
            string: "\(count) \(count == 1 ? "contact" : "contacts")", attributes: bold)
        let nameList: String
        if count <= 2 {
            nameList = contacts.map(\.name).joined(separator: ", ")
        } else {
            let others = count - 2
            nameList = "\(contacts[0].name), \(contacts[1].name) & \(others) \(others == 1 ? "other" : "others")"
        }
        result.append(NSAttributedString(string: " · \(nameList)", attributes: secondary))
        return result
    }

}
