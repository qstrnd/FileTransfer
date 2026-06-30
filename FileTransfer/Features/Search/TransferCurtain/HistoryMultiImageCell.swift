import UIKit

final class HistoryMultiImageCell: HistoryBaseCell {

    private static let thumbSize: CGFloat = 120
    private static let maxThumbs = 10

    private var loadTasks: [Task<Void, Never>] = []
    private var currentURLs: [URL] = []
    private var thumbViews: [UIImageView] = []

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.clipsToBounds = true
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
            iv.widthAnchor.constraint(equalToConstant: Self.thumbSize).isActive = true
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
    }

    // MARK: - Private

    private func setupContent() {
        scrollView.addSubview(thumbsStack)
        contentContainer.addSubview(scrollView)
        contentContainer.addSubview(metaLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: Self.thumbSize),

            thumbsStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            thumbsStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            thumbsStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            thumbsStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            thumbsStack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),

            metaLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 6),
            metaLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            metaLabel.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -10),
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
