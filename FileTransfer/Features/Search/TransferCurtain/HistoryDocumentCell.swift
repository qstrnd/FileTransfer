import UIKit

final class HistoryDocumentCell: HistoryBaseCell {

    private var cardView: DocumentCardView?
    private var currentURL: URL?

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

    override func shouldDisplayMoreButton() -> Bool { true }

    // MARK: - Configure

    func configure(with record: TransferRecord, gate: any HistoryThumbnailGate) {
        super.configure(with: record)

        let url = record.attachmentURLs.first
        currentURL = url
        metaLabel.text = metaText(for: record)

        if let url {
            if let existing = cardView {
                existing.reconfigure(for: url)
                existing.load(using: gate)
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cardView?.cancelLoad()
        currentURL = nil
        metaLabel.text = nil
    }

    // MARK: - Layout

    private func setupContent() {
        // DocumentCardView is created once with a placeholder URL;
        // configure() calls reconfigure(for:) to swap the real URL in.
        let placeholder = URL(string: "about:blank")!
        let card = DocumentCardView(url: placeholder, index: 0, cornerRadius: 12)
        card.translatesAutoresizingMaskIntoConstraints = false
        cardView = card

        contentContainer.addSubview(card)
        contentContainer.addSubview(metaLabel)

        NSLayoutConstraint.activate([
            // Top edge aligned to the mid-height of the Sent/Received badge.
            card.topAnchor.constraint(equalTo: statusBadge.centerYAnchor),
            card.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            card.heightAnchor.constraint(equalToConstant: 120),

            // Gap leaves room for the overflow button in the meta row.
            metaLabel.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 12),
            metaLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            metaLabel.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -10),
        ])
    }

    // MARK: - Private

    private func metaText(for record: TransferRecord) -> String {
        let name = record.attachmentURLs.first?.lastPathComponent ?? record.detail ?? ""
        guard let bytes = record.fileBytes else { return name }
        return "\(name) · \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))"
    }
}
