import UIKit

final class HistoryDocumentCell: HistoryBaseCell {

    private var loadTask: Task<Void, Never>?
    private var currentURL: URL?

    // MARK: - Card

    private let card: UIView = {
        let v = UIView()
        v.backgroundColor = .secondarySystemFill
        v.layer.cornerRadius = 12
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let previewImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .systemGroupedBackground
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let typeBadge: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .bold)
        l.textColor = .white
        l.textAlignment = .center
        l.layer.cornerRadius = 4
        l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
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
        previewImageView.image = nil

        let url = record.attachmentURLs.first
        currentURL = url
        metaLabel.text = metaText(for: record)
        configureTypeBadge(for: url)

        guard let url else { return }
        loadTask?.cancel()
        loadTask = Task { @MainActor [weak self] in
            guard let data = await gate.thumbnail(for: url),
                  let img = UIImage(data: data) else { return }
            guard self?.currentURL == url else { return }
            UIView.transition(with: self?.previewImageView ?? UIView(),
                              duration: 0.2,
                              options: .transitionCrossDissolve) {
                self?.previewImageView.image = img
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        loadTask = nil
        currentURL = nil
        previewImageView.image = nil
        metaLabel.text = nil
        typeBadge.text = nil
    }

    // MARK: - Private

    private func setupContent() {
        card.addSubview(previewImageView)
        card.addSubview(typeBadge)
        contentView.addSubview(card)
        contentView.addSubview(metaLabel)

        NSLayoutConstraint.activate([
            // Card: left edge to right edge, 4:3 aspect ratio
            card.topAnchor.constraint(equalTo: contentTop, constant: 8),
            card.leadingAnchor.constraint(equalTo: contentLeading, constant: contentInsetLeading),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.heightAnchor.constraint(equalTo: card.widthAnchor, multiplier: 3.0 / 4.0),

            // Preview fills the card
            previewImageView.topAnchor.constraint(equalTo: card.topAnchor),
            previewImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            // Type badge: top-right corner of card
            typeBadge.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            typeBadge.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            typeBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 36),
            typeBadge.heightAnchor.constraint(equalToConstant: 20),

            // Meta label below card
            metaLabel.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 6),
            metaLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            metaLabel.bottomAnchor.constraint(equalTo: contentBottom, constant: -12),
        ])
    }

    private func configureTypeBadge(for url: URL?) {
        let ext = (url?.pathExtension ?? "").uppercased()
        let label = ext.isEmpty ? "FILE" : ext
        typeBadge.text = "  \(label)  "
        typeBadge.backgroundColor = badgeColor(for: ext)
    }

    private func badgeColor(for ext: String) -> UIColor {
        switch ext {
        case "PDF":  return UIColor(red: 0.86, green: 0.20, blue: 0.18, alpha: 1)
        case "DOC", "DOCX": return UIColor(red: 0.17, green: 0.45, blue: 0.90, alpha: 1)
        case "XLS", "XLSX": return UIColor(red: 0.13, green: 0.60, blue: 0.35, alpha: 1)
        case "PPT", "PPTX": return UIColor(red: 0.91, green: 0.38, blue: 0.17, alpha: 1)
        case "ZIP", "RAR":  return UIColor(red: 0.55, green: 0.40, blue: 0.80, alpha: 1)
        default:             return UIColor(red: 0.40, green: 0.40, blue: 0.44, alpha: 1)
        }
    }

    private func metaText(for record: TransferRecord) -> String {
        let name = record.attachmentURLs.first?.lastPathComponent ?? record.detail ?? ""
        guard let bytes = record.fileBytes else { return name }
        return "\(name) · \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))"
    }
}
