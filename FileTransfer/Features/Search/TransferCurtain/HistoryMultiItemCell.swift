import UIKit

// Horizontal gradient that fades from the curtain background (opaque) on one edge to clear.
private final class EdgeGradientView: UIView {
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
        // CAGradientLayer doesn't always redisplay immediately from a plain
        // property assignment when the change originates from a trait-change
        // callback rather than a normal render pass — force it explicitly.
        gradientLayer.setNeedsDisplay()
    }

    @objc private func appWillEnterForeground() { updateColors(for: traitCollection) }
}

/// Multi-item horizontal strip cell — supports both photo thumbnails and document cards.
final class HistoryMultiItemCell: HistoryBaseCell {

    enum ContentKind { case photo, document }

    private static let fixedItemSize: CGFloat = 120
    private static let maxItems = 10
    // Must match the scrollView.contentInset values below.
    private static let scrollLeftInset:  CGFloat = 72
    private static let scrollRightInset: CGFloat = 106
    private static let itemSpacing:      CGFloat = 4
    private static let edgeGradientWidth: CGFloat = 32

    /// Called when an item is tapped. Argument is the index within `record.attachmentURLs`.
    var onItemTap: ((Int) -> Void)?

    private var contentKind: ContentKind = .photo
    private var photoLoadTasks: [Task<Void, Never>] = []
    private var documentCards:  [DocumentCardView] = []
    private var currentURLs: [URL] = []
    private var imageViews:  [UIImageView] = []   // photo image views only

    private let leftGradient  = EdgeGradientView(isLeading: true)
    private let rightGradient = EdgeGradientView(isLeading: false)

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.clipsToBounds = true
        sv.alwaysBounceHorizontal = true
        // left:  16 (cell leading) + 44 (avatar) + 12 (gap)  = 72 pt
        // right: 16 (cell trailing) + 90 (badge/time column)  = 106 pt
        sv.contentInset = UIEdgeInsets(top: 0, left: 72, bottom: 0, right: 106)
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let thumbsStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 4
        sv.alignment = .fill
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let metaLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupContent()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Configure

    func configure(with record: TransferRecord, gate: any HistoryThumbnailGate) {
        super.configure(with: record)
        cancelLoad()
        clearItems()

        contentKind = record.type == .file ? .document : .photo

        let urls = Array(record.attachmentURLs.prefix(Self.maxItems))
        currentURLs = urls
        metaLabel.text = metaText(for: record, count: urls.count)

        let twoItems = urls.count == 2

        for (idx, url) in urls.enumerated() {
            let itemView: UIView
            switch contentKind {
            case .photo:
                let (view, iv) = makePhotoView(index: idx)
                itemView = view
                imageViews.append(iv)
                photoLoadTasks.append(Task { @MainActor [weak self] in
                    guard let data = await gate.thumbnail(for: url),
                          let img = UIImage(data: data) else { return }
                    guard self?.currentURLs.indices.contains(idx) == true,
                          self?.currentURLs[idx] == url else { return }
                    UIView.transition(with: iv, duration: 0.2,
                                      options: .transitionCrossDissolve) { iv.image = img }
                })
            case .document:
                let card = DocumentCardView(url: url, index: idx)
                card.onTap = { [weak self] i in self?.onItemTap?(i) }
                documentCards.append(card)
                itemView = card
                card.load(using: gate)
            }

            // For exactly 2 items, size each so both fit the visible strip without scrolling.
            let widthConstraint: NSLayoutConstraint
            if twoItems {
                let c = -(Self.scrollLeftInset + Self.scrollRightInset + Self.itemSpacing) / 2
                widthConstraint = NSLayoutConstraint(
                    item: itemView, attribute: .width,
                    relatedBy: .equal,
                    toItem: scrollView.frameLayoutGuide, attribute: .width,
                    multiplier: 0.5, constant: c
                )
            } else {
                widthConstraint = itemView.widthAnchor.constraint(equalToConstant: Self.fixedItemSize)
            }
            thumbsStack.addArrangedSubview(itemView)
            widthConstraint.isActive = true
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cancelLoad()
        clearItems()
        currentURLs = []
        metaLabel.text = nil
        onItemTap = nil
    }

    // MARK: - Tap (photos only — DocumentCardView handles its own tap)

    @objc private func didTapPhoto(_ sender: UITapGestureRecognizer) {
        guard let v = sender.view else { return }
        UIView.animate(withDuration: 0.1, animations: { v.alpha = 0.65 },
                       completion: { _ in UIView.animate(withDuration: 0.12) { v.alpha = 1.0 } })
        onItemTap?(v.tag)
    }

    // MARK: - Layout setup

    private func setupContent() {
        scrollView.addSubview(thumbsStack)
        contentView.insertSubview(scrollView, belowSubview: avatarContainer)
        contentView.insertSubview(leftGradient,  aboveSubview: scrollView)
        contentView.insertSubview(rightGradient, aboveSubview: leftGradient)
        contentContainer.addSubview(metaLabel)

        let gw = Self.edgeGradientWidth
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: Self.fixedItemSize),

            thumbsStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            thumbsStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            thumbsStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            thumbsStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            thumbsStack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),

            leftGradient.topAnchor.constraint(equalTo: scrollView.topAnchor),
            leftGradient.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            leftGradient.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            leftGradient.widthAnchor.constraint(equalToConstant: gw),

            rightGradient.topAnchor.constraint(equalTo: scrollView.topAnchor),
            rightGradient.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            rightGradient.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rightGradient.widthAnchor.constraint(equalToConstant: gw),

            metaLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 6),
            metaLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            metaLabel.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -10),
        ])

        leftGradient.updateColors(for: traitCollection)
        rightGradient.updateColors(for: traitCollection)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (_: HistoryMultiItemCell, tc: UITraitCollection) in
            guard let self else { return }
            leftGradient.updateColors(for: tc)
            rightGradient.updateColors(for: tc)
        }
    }

    // MARK: - Photo view factory

    private func makePhotoView(index: Int) -> (UIView, UIImageView) {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .secondarySystemFill
        iv.layer.cornerRadius = 6
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isUserInteractionEnabled = true
        iv.tag = index
        iv.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapPhoto(_:))))
        addVeil(to: iv)
        return (iv, iv)
    }

    // MARK: - Helpers

    /// Dark-mode-only veil so a bright photo doesn't look glaringly out of
    /// place against the curtain's darker background. Passthrough in light mode.
    /// (DocumentCardView applies its own equivalent veil for the .document kind.)
    private func addVeil(to view: UIView) {
        let veil = UIView()
        veil.isUserInteractionEnabled = false
        veil.backgroundColor = .curtainDarkModeVeil
        veil.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(veil)
        NSLayoutConstraint.activate([
            veil.topAnchor.constraint(equalTo: view.topAnchor),
            veil.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            veil.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            veil.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func cancelLoad() {
        photoLoadTasks.forEach { $0.cancel() }
        photoLoadTasks = []
        documentCards.forEach { $0.cancelLoad() }
    }

    private func clearItems() {
        thumbsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        imageViews = []
        documentCards = []
    }

    private func metaText(for record: TransferRecord, count: Int) -> String {
        let noun: String
        switch contentKind {
        case .photo:     noun = count == 1 ? "photo"    : "photos"
        case .document:  noun = count == 1 ? "file"     : "files"
        }
        let countStr = "\(count) \(noun)"
        guard let bytes = record.fileBytes else { return countStr }
        return "\(countStr) · \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))"
    }
}
