import UIKit

/// Reusable document-preview tile used by HistoryDocumentCell, HistoryMultiItemCell,
/// and the received-file alert. Shows an async thumbnail (via HistoryThumbnailGate)
/// with a colour-coded extension badge in the top-right corner.
final class DocumentCardView: UIView {

    // MARK: - Public

    private(set) var url: URL
    let index: Int
    var onTap: ((Int) -> Void)?

    // MARK: - Private

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let badge: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 10, weight: .bold)
        l.textColor = .white
        l.textAlignment = .center
        l.layer.cornerRadius = 4
        l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    /// Dark-mode-only veil over the thumbnail so a bright document preview
    /// doesn't look glaringly out of place against the curtain's darker
    /// background. Sits above the image but below the badge, which stays
    /// fully legible. Passthrough (clear) in light mode.
    private let veil: UIView = {
        let v = UIView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .curtainDarkModeVeil
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private var loadTask: Task<Void, Never>?

    // MARK: - Init

    /// - Parameters:
    ///   - url: File whose extension drives the badge colour; thumbnail loaded on demand.
    ///   - index: Forwarded to `onTap`. Use the item's position in its parent list.
    ///   - cornerRadius: 8 (multi-item strip) or 12 (full-width document cell).
    init(url: URL, index: Int = 0, cornerRadius: CGFloat = 8) {
        self.url = url
        self.index = index
        super.init(frame: .zero)
        setup(cornerRadius: cornerRadius)
        applyBadge()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Reconfigure (cell-reuse pattern used by HistoryDocumentCell)

    func reconfigure(for newURL: URL) {
        cancelLoad()
        imageView.image = nil
        url = newURL
        applyBadge()
    }

    // MARK: - Thumbnail loading

    func load(using gate: any HistoryThumbnailGate) {
        let target = url
        loadTask?.cancel()
        loadTask = Task { @MainActor [weak self] in
            guard let data = await gate.thumbnail(for: target),
                  let img = UIImage(data: data) else { return }
            guard let self, self.url == target else { return }
            UIView.transition(with: self.imageView, duration: 0.2,
                              options: .transitionCrossDissolve) { self.imageView.image = img }
        }
    }

    func cancelLoad() {
        loadTask?.cancel()
        loadTask = nil
    }

    // MARK: - Private setup

    private func setup(cornerRadius: CGFloat) {
        backgroundColor = .secondarySystemFill
        layer.cornerRadius = cornerRadius
        layer.borderWidth = 0.33
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false
        tag = index
        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))

        addSubview(imageView)
        addSubview(veil)
        addSubview(badge)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            veil.topAnchor.constraint(equalTo: topAnchor),
            veil.leadingAnchor.constraint(equalTo: leadingAnchor),
            veil.trailingAnchor.constraint(equalTo: trailingAnchor),
            veil.bottomAnchor.constraint(equalTo: bottomAnchor),
            badge.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            badge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
        ])

        refreshBorderColor(for: traitCollection)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (_: DocumentCardView, _: UITraitCollection) in
            // The handler's second parameter is the *previous* trait collection,
            // not the new one — read self.traitCollection, already updated by now.
            guard let self else { return }
            refreshBorderColor(for: traitCollection)
        }
        NotificationCenter.default.addObserver(self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil)
    }

    private func applyBadge() {
        let ext = url.pathExtension.uppercased()
        badge.text = "  \(ext.isEmpty ? "FILE" : ext)  "
        badge.backgroundColor = Self.badgeColor(for: ext)
    }

    @objc private func handleTap() { onTap?(index) }

    private func refreshBorderColor(for tc: UITraitCollection) {
        layer.borderColor = UIColor.separator.resolvedColor(with: tc).withAlphaComponent(0.35).cgColor
    }

    @objc private func appWillEnterForeground() { refreshBorderColor(for: traitCollection) }

    // MARK: - Shared badge colours

    static func badgeColor(for ext: String) -> UIColor {
        switch ext {
        case "PDF":             return UIColor(red: 0.86, green: 0.20, blue: 0.18, alpha: 1)
        case "DOC", "DOCX":    return UIColor(red: 0.17, green: 0.45, blue: 0.90, alpha: 1)
        case "XLS", "XLSX":    return UIColor(red: 0.13, green: 0.60, blue: 0.35, alpha: 1)
        case "PPT", "PPTX":    return UIColor(red: 0.91, green: 0.38, blue: 0.17, alpha: 1)
        case "ZIP", "RAR":     return UIColor(red: 0.55, green: 0.40, blue: 0.80, alpha: 1)
        default:               return UIColor(red: 0.40, green: 0.40, blue: 0.44, alpha: 1)
        }
    }
}
