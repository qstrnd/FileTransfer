import UIKit

final class HistoryImageCell: HistoryBaseCell {

    var thumbnailGate: (any HistoryThumbnailGate)?

    private var loadTask: Task<Void, Never>?
    private var currentURL: URL?

    private let thumbnailView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .secondarySystemFill
        iv.layer.cornerRadius = 8
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
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
        thumbnailGate = gate
        thumbnailView.image = nil

        let url = record.attachmentURLs.first
        currentURL = url
        metaLabel.text = metaText(for: record)

        guard let url else { return }
        loadTask?.cancel()
        loadTask = Task { @MainActor [weak self] in
            guard let data = await gate.thumbnail(for: url),
                  let img = UIImage(data: data) else { return }
            guard self?.currentURL == url else { return }
            UIView.transition(with: self?.thumbnailView ?? UIView(),
                              duration: 0.2,
                              options: .transitionCrossDissolve) {
                self?.thumbnailView.image = img
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        loadTask = nil
        currentURL = nil
        thumbnailView.image = nil
        metaLabel.text = nil
        thumbnailGate = nil
    }

    // MARK: - Private

    private func setupContent() {
        contentContainer.addSubview(thumbnailView)
        contentContainer.addSubview(metaLabel)

        NSLayoutConstraint.activate([
            thumbnailView.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 4),
            thumbnailView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            thumbnailView.heightAnchor.constraint(equalToConstant: 160),

            metaLabel.topAnchor.constraint(equalTo: thumbnailView.bottomAnchor, constant: 6),
            metaLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            metaLabel.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -10),
        ])
    }

    private func metaText(for record: TransferRecord) -> String {
        let name = record.attachmentURLs.first?.lastPathComponent ?? record.detail ?? ""
        guard let bytes = record.fileBytes else { return name }
        return "\(name) · \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))"
    }
}
