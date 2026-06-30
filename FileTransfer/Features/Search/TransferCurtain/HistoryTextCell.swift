import UIKit

final class HistoryTextCell: HistoryBaseCell {

    /// Called when the cell expands/collapses so the layout can be invalidated.
    var onSizeChange: (() -> Void)?

    private var isExpanded = false

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
        updateMoreButton()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        bodyLabel.text = nil
        isExpanded = false
        bodyLabel.numberOfLines = 2
        onSizeChange = nil
        moreButton.isHidden = false
    }

    // MARK: - Private

    private func setupContent() {
        contentView.addSubview(bodyLabel)
        contentView.addSubview(moreButton)

        NSLayoutConstraint.activate([
            bodyLabel.topAnchor.constraint(equalTo: contentTop, constant: 0),
            bodyLabel.leadingAnchor.constraint(equalTo: contentLeading, constant: contentInsetLeading),
            bodyLabel.trailingAnchor.constraint(equalTo: contentTrailing, constant: contentInsetTrailing),

            moreButton.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 2),
            moreButton.leadingAnchor.constraint(equalTo: bodyLabel.leadingAnchor),
            moreButton.bottomAnchor.constraint(equalTo: contentBottom, constant: -12),
        ])
    }

    private func toggle() {
        isExpanded.toggle()
        bodyLabel.numberOfLines = isExpanded ? 0 : 2
        updateMoreButton()
        onSizeChange?()
    }

    private func updateMoreButton() {
        var config = moreButton.configuration
        config?.title = isExpanded ? "less" : "more"
        moreButton.configuration = config
    }
}
