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
        // CGColor snapshots don't re-resolve on their own if the system
        // appearance changes while the app is backgrounded — refresh on return.
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

final class HistoryMultiMediaCell: HistoryBaseCell {

    private static let thumbSize: CGFloat = 120
    private static let maxThumbs = 10

    /// Called when the user taps a thumbnail. The argument is the index within `record.attachmentURLs`.
    var onThumbnailTap: ((Int) -> Void)?

    private static let edgeGradientWidth: CGFloat = 32

    private let leftGradient  = EdgeGradientView(isLeading: true)
    private let rightGradient = EdgeGradientView(isLeading: false)

    private var loadTasks: [Task<Void, Never>] = []
    private var currentURLs: [URL] = []
    private var thumbViews: [UIImageView] = []

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.clipsToBounds = true
        sv.alwaysBounceHorizontal = true
        // left:  16 (cell leading) + 44 (avatar) + 12 (gap)  = 72 pt — rest starts after peer bubble
        // right: 16 (cell trailing) + 90 (badge/time column)  = 106 pt — rest ends before right labels
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
        clearThumbs()

        let urls = Array(record.attachmentURLs.prefix(Self.maxThumbs))
        currentURLs = urls
        metaLabel.text = metaText(for: record)

        for (idx, url) in urls.enumerated() {
            let iv = UIImageView()
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.backgroundColor = .secondarySystemFill
            iv.layer.cornerRadius = 6
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.isUserInteractionEnabled = true
            iv.tag = idx
            iv.widthAnchor.constraint(equalToConstant: Self.thumbSize).isActive = true
            iv.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapThumb(_:))))
            addVeil(to: iv)
            thumbsStack.addArrangedSubview(iv)
            thumbViews.append(iv)

            loadTasks.append(Task { @MainActor [weak self] in
                guard let data = await gate.thumbnail(for: url),
                      let img = UIImage(data: data) else { return }
                guard self?.currentURLs.indices.contains(idx) == true,
                      self?.currentURLs[idx] == url else { return }
                let view = self?.thumbViews[idx]
                UIView.transition(with: view ?? UIView(),
                                  duration: 0.2,
                                  options: .transitionCrossDissolve) {
                    view?.image = img
                }
            })
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cancelLoad()
        clearThumbs()
        currentURLs = []
        metaLabel.text = nil
        onThumbnailTap = nil
    }

    // MARK: - Actions

    @objc private func didTapThumb(_ sender: UITapGestureRecognizer) {
        guard let iv = sender.view else { return }
        UIView.animate(withDuration: 0.1, animations: {
            iv.alpha = 0.65
        }, completion: { _ in
            UIView.animate(withDuration: 0.12) { iv.alpha = 1.0 }
        })
        onThumbnailTap?(iv.tag)
    }

    // MARK: - Private

    private func setupContent() {
        scrollView.addSubview(thumbsStack)
        // scrollView sits below avatar/badge in Z-order; gradients go directly above it.
        contentView.insertSubview(scrollView, belowSubview: avatarContainer)
        contentView.insertSubview(leftGradient,  aboveSubview: scrollView)
        contentView.insertSubview(rightGradient, aboveSubview: leftGradient)
        contentContainer.addSubview(metaLabel)

        let gw = Self.edgeGradientWidth
        NSLayoutConstraint.activate([
            // Span full cell width; contentInset.left keeps the rest position after the peer bubble.
            scrollView.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: Self.thumbSize),

            thumbsStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            thumbsStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            thumbsStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            thumbsStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            thumbsStack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),

            // Left gradient: opaque at the cell's leading edge, fading right.
            leftGradient.topAnchor.constraint(equalTo: scrollView.topAnchor),
            leftGradient.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            leftGradient.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            leftGradient.widthAnchor.constraint(equalToConstant: gw),

            // Right gradient: opaque at the cell's trailing edge, fading left.
            rightGradient.topAnchor.constraint(equalTo: scrollView.topAnchor),
            rightGradient.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            rightGradient.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rightGradient.widthAnchor.constraint(equalToConstant: gw),

            metaLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 6),
            metaLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            metaLabel.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -10),
        ])

        // Apply gradient colors now and whenever the color scheme changes.
        leftGradient.updateColors(for: traitCollection)
        rightGradient.updateColors(for: traitCollection)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (_: HistoryMultiMediaCell, _: UITraitCollection) in
            guard let self else { return }
            leftGradient.updateColors(for: traitCollection)
            rightGradient.updateColors(for: traitCollection)
        }
    }

    /// Dark-mode-only veil so a bright photo doesn't look glaringly out of
    /// place against the curtain's darker background. Passthrough in light mode.
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
        loadTasks.forEach { $0.cancel() }
        loadTasks = []
    }

    private func clearThumbs() {
        thumbsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        thumbViews = []
    }

    private func metaText(for record: TransferRecord) -> String {
        let count = record.attachmentURLs.count
        let countStr = "\(count) \(count == 1 ? "photo" : "photos")"
        guard let bytes = record.fileBytes else { return countStr }
        return "\(countStr) · \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))"
    }
}
