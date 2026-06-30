import UIKit

final class HistoryMultiImageCell: HistoryBaseCell {

    private static let maxThumbs = 3

    private var loadTasks: [Task<Void, Never>] = []
    private var currentURLs: [URL] = []

    private let thumbStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 4
        sv.distribution = .fillEqually
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let thumbViews: [UIImageView] = (0..<maxThumbs).map { _ in
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .secondarySystemFill
        iv.layer.cornerRadius = 6
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }

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
        thumbViews.forEach { thumbStack.addArrangedSubview($0) }
        setupContent()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Configure

    func configure(with record: TransferRecord, gate: any HistoryThumbnailGate) {
        super.configure(with: record)
        cancelLoad()
        thumbViews.forEach { $0.image = nil; $0.isHidden = false }

        let urls = Array(record.attachmentURLs.prefix(Self.maxThumbs))
        currentURLs = urls

        // Hide unused thumb slots
        for i in urls.count..<Self.maxThumbs {
            thumbViews[i].isHidden = true
        }

        metaLabel.text = metaText(for: record)

        loadTasks = urls.enumerated().map { idx, url in
            Task { @MainActor [weak self] in
                guard let data = await gate.thumbnail(for: url),
                      let img = UIImage(data: data) else { return }
                guard self?.currentURLs.indices.contains(idx) == true,
                      self?.currentURLs[idx] == url else { return }
                let iv = self?.thumbViews[idx]
                UIView.transition(with: iv ?? UIView(),
                                  duration: 0.2,
                                  options: .transitionCrossDissolve) {
                    iv?.image = img
                }
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cancelLoad()
        currentURLs = []
        thumbViews.forEach { $0.image = nil; $0.isHidden = false }
        metaLabel.text = nil
    }

    // MARK: - Private

    private func setupContent() {
        contentView.addSubview(thumbStack)
        contentView.addSubview(metaLabel)

        NSLayoutConstraint.activate([
            thumbStack.topAnchor.constraint(equalTo: contentTop, constant: 8),
            thumbStack.leadingAnchor.constraint(equalTo: contentLeading, constant: contentInsetLeading),
            thumbStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            thumbStack.heightAnchor.constraint(equalTo: thumbStack.widthAnchor, multiplier: 1.0 / 3.0),

            metaLabel.topAnchor.constraint(equalTo: thumbStack.bottomAnchor, constant: 6),
            metaLabel.leadingAnchor.constraint(equalTo: thumbStack.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: thumbStack.trailingAnchor),
            metaLabel.bottomAnchor.constraint(equalTo: contentBottom, constant: -12),
        ])
    }

    private func cancelLoad() {
        loadTasks.forEach { $0.cancel() }
        loadTasks = []
    }

    private func metaText(for record: TransferRecord) -> String {
        let count = record.attachmentURLs.count
        let countStr = "\(count) \(count == 1 ? "photo" : "photos")"
        guard let bytes = record.fileBytes else { return countStr }
        return "\(countStr) · \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))"
    }
}
