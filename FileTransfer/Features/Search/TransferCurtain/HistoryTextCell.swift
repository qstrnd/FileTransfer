import UIKit

final class HistoryTextCell: HistoryBaseCell {

    var onSizeChange: (() -> Void)?

    private var isExpanded = false
    private var lastHiddenState = true

    private let bodyLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15)
        l.textColor = .label
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
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
        // Force a full layout pass so bodyLabel.bounds.width is known before
        // the collection view queries our preferred size. This lets layoutSubviews
        // correctly show/hide moreButton, which affects the returned height.
        setNeedsLayout()
        layoutIfNeeded()
        return super.preferredLayoutAttributesFitting(layoutAttributes)
    }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupContent()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Configure

    override func configure(with record: TransferRecord) {
        super.configure(with: record)
        bodyLabel.text = record.detail
        isExpanded = false
        bodyLabel.numberOfLines = 2
        // Hide until layoutSubviews confirms overflow; stack collapses the button space.
        moreButton.isHidden = true
        lastHiddenState = true
        updateMoreButtonTitle()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !isExpanded, bodyLabel.bounds.width > 0 else { return }
        let shouldHide = !textOverflows(bodyLabel.text ?? "", width: bodyLabel.bounds.width)
        guard shouldHide != lastHiddenState else { return }
        lastHiddenState = shouldHide
        moreButton.isHidden = shouldHide
        // Stack height changed — tell the layout to re-query cell size.
        onSizeChange?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        bodyLabel.text = nil
        isExpanded = false
        bodyLabel.numberOfLines = 2
        moreButton.isHidden = true
        lastHiddenState = true
        onSizeChange = nil
    }

    // MARK: - Private

    private func setupContent() {
        bodyStack.addArrangedSubview(bodyLabel)
        bodyStack.addArrangedSubview(moreButton)
        contentView.addSubview(bodyStack)

        NSLayoutConstraint.activate([
            bodyStack.topAnchor.constraint(equalTo: contentTop, constant: 4),
            bodyStack.leadingAnchor.constraint(equalTo: contentLeading, constant: contentInsetLeading),
            bodyStack.trailingAnchor.constraint(equalTo: contentTrailing, constant: contentInsetTrailing),
            bodyStack.bottomAnchor.constraint(equalTo: contentBottom, constant: -12),

            // bodyLabel fills the stack width; moreButton only as wide as its title.
            bodyLabel.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
        ])
    }

    private func toggle() {
        isExpanded.toggle()
        bodyLabel.numberOfLines = isExpanded ? 0 : 2
        if !isExpanded {
            // After collapsing, re-evaluate overflow to decide if button stays visible.
            moreButton.isHidden = !textOverflows(bodyLabel.text ?? "", width: bodyLabel.bounds.width)
            lastHiddenState = moreButton.isHidden
        }
        updateMoreButtonTitle()
        onSizeChange?()
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
