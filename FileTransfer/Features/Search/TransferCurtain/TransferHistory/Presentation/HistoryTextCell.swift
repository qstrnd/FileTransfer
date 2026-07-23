import UIKit

final class HistoryTextCell: HistoryBaseCell {

    var onSizeChange: (() -> Void)?

    private var isExpanded = false
    private var lastHiddenState = true
    private var isSizingPass = false

    // A UITextView (not UILabel) so the transferred text can be selected and
    // copied, like Messages/Mail — configured to look and size like a plain
    // label (no scrolling, no editing, no insets).
    private let bodyLabel: UITextView = {
        let tv = UITextView()
        tv.font = .systemFont(ofSize: 15)
        tv.textColor = .label
        tv.backgroundColor = .clear
        tv.isEditable = false
        tv.isSelectable = true
        tv.isScrollEnabled = false
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainer.maximumNumberOfLines = 2
        tv.textContainer.lineBreakMode = .byTruncatingTail
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private lazy var moreButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "more"
        config.baseForegroundColor = .systemBlue
        config.contentInsets = .zero
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs
            a.font = UIFont.systemFont(ofSize: 14)
            return a
        }
        let b = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            self?.toggle()
        })
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setContentHuggingPriority(.required, for: .horizontal)
        return b
    }()

    // UIStackView collapses hidden arranged subviews including their spacing.
    private let bodyStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 2
        sv.alignment = .leading
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - Self-sizing

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        // Force a full layout pass so bodyLabel.bounds.width is known before the
        // collection view queries our preferred size. isSizingPass suppresses the
        // onSizeChange → performBatchUpdates call that would fire from layoutSubviews
        // here, which would crash because the cell hasn't been returned yet.
        isSizingPass = true
        defer { isSizingPass = false }
        setNeedsLayout()
        layoutIfNeeded()
        return super.preferredLayoutAttributesFitting(layoutAttributes)
    }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Clip so text doesn't bleed outside the animating cell frame during expand/collapse.
        contentView.clipsToBounds = true
        setupContent()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Configure

    override func configure(with record: TransferRecord) {
        super.configure(with: record)
        bodyLabel.text = record.detail
        isExpanded = false
        setLineLimit(2)
        // Hide until layoutSubviews confirms overflow; stack collapses the button space.
        moreButton.isHidden = true
        lastHiddenState = true
        updateMoreButtonTitle()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bodyLabel.bounds.width > 0 else { return }
        updateTextVerticalCentering()
        guard !isExpanded else { return }
        let shouldHide = !textOverflows(bodyLabel.text ?? "", width: bodyLabel.bounds.width)
        guard shouldHide != lastHiddenState else { return }
        lastHiddenState = shouldHide
        moreButton.isHidden = shouldHide
        // During preferredLayoutAttributesFitting the correct size is already
        // being computed; calling performBatchUpdates before the cell is returned
        // to the collection view would crash.
        guard !isSizingPass else { return }
        onSizeChange?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        bodyLabel.text = nil
        isExpanded = false
        setLineLimit(2)
        moreButton.isHidden = true
        lastHiddenState = true
        onSizeChange = nil
    }

    // MARK: - Private

    private func setupContent() {
        bodyStack.addArrangedSubview(bodyLabel)
        bodyStack.addArrangedSubview(moreButton)
        contentContainer.addSubview(bodyStack)

        NSLayoutConstraint.activate([
            bodyStack.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 4),
            bodyStack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            bodyStack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            bodyStack.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -12),

            bodyLabel.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
        ])
    }

    private func toggle() {
        isExpanded.toggle()
        let expanding = isExpanded
        // Apply state changes without animation so they don't get swept into
        // any ambient UIView.animate context. Only the cell height (via
        // performBatchUpdates in onSizeChange) should animate.
        UIView.performWithoutAnimation {
            setLineLimit(expanding ? 0 : 2)
            if !expanding {
                moreButton.isHidden = !textOverflows(bodyLabel.text ?? "", width: bodyLabel.bounds.width)
                lastHiddenState = moreButton.isHidden
            }
            updateMoreButtonTitle()
        }
        onSizeChange?()
    }

    /// When collapsed, the row is often taller than the 1–2 lines of text it
    /// holds (e.g. to fit the 44pt avatar), and bodyLabel — the flexible
    /// element in bodyStack — absorbs that slack, growing past its text's own
    /// height. UITextView top-aligns by default, so without this the text
    /// sits high in the extra space instead of centered in it. Only applies
    /// pre-expand: once expanded, the row grows to fit all the text, so
    /// there's no slack left to center within.
    private func updateTextVerticalCentering() {
        guard !isExpanded else {
            bodyLabel.textContainerInset = .zero
            return
        }
        bodyLabel.layoutManager.ensureLayout(for: bodyLabel.textContainer)
        let textHeight = bodyLabel.layoutManager.usedRect(for: bodyLabel.textContainer).height
        let topInset = max(0, (bodyLabel.bounds.height - textHeight) / 2)
        bodyLabel.textContainerInset = UIEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
    }

    private func setLineLimit(_ maxLines: Int) {
        bodyLabel.textContainer.maximumNumberOfLines = maxLines
        bodyLabel.textContainer.lineBreakMode = maxLines == 0 ? .byWordWrapping : .byTruncatingTail
        // Unlike UILabel.numberOfLines, mutating the text container doesn't
        // invalidate UITextView's cached intrinsic size on its own — without
        // this, toggling the line limit alone (i.e. not paired with a new
        // `text` assignment, which does invalidate) leaves the cell's height
        // stuck, so "more"/"less" never visibly expands or collapses it.
        bodyLabel.invalidateIntrinsicContentSize()
    }

    private func updateMoreButtonTitle() {
        var config = moreButton.configuration
        config?.title = isExpanded ? "less" : "more"
        moreButton.configuration = config
    }

    /// True when `text` needs more than 2 lines at `width`.
    private func textOverflows(_ text: String, width: CGFloat) -> Bool {
        guard !text.isEmpty else { return false }
        let font = bodyLabel.font ?? .systemFont(ofSize: 15)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let twoLineH = font.lineHeight * 2 + font.leading + 2
        let fullH = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        ).height
        return fullH > twoLineH
    }
}
