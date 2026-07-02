#if DEBUG
import SwiftUI
import UIKit

// MARK: - Colored placeholder thumbnail gate

private final class PreviewThumbnailGate: HistoryThumbnailGate, @unchecked Sendable {
    private let palette: [UIColor] = [
        UIColor(red: 0.36, green: 0.58, blue: 0.93, alpha: 1), // blue
        UIColor(red: 0.30, green: 0.73, blue: 0.54, alpha: 1), // green
        UIColor(red: 0.96, green: 0.62, blue: 0.28, alpha: 1), // orange
        UIColor(red: 0.72, green: 0.47, blue: 0.89, alpha: 1), // purple
        UIColor(red: 0.93, green: 0.38, blue: 0.38, alpha: 1), // red
        UIColor(red: 0.25, green: 0.72, blue: 0.82, alpha: 1), // teal
    ]

    func thumbnail(for url: URL) async -> Data? {
        let idx = abs(url.absoluteString.hashValue) % palette.count
        let color = palette[idx]
        let size = CGSize(width: 600, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.jpegData(withCompressionQuality: 0.85) { ctx in
            // Solid background
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            // Subtle diagonal stripe pattern
            UIColor.white.withAlphaComponent(0.12).setFill()
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                let stripe = UIBezierPath()
                stripe.move(to: CGPoint(x: x, y: 0))
                stripe.addLine(to: CGPoint(x: x + 40, y: 0))
                stripe.addLine(to: CGPoint(x: x + 40 + size.height, y: size.height))
                stripe.addLine(to: CGPoint(x: x + size.height, y: size.height))
                stripe.close()
                stripe.fill()
                x += 80
            }
        }
    }

    func prefetch(_ urls: [URL]) {}
}

// MARK: - Mock records

private func url(_ name: String) -> URL { URL(string: "file:///preview/\(name)")! }

private func records() -> [TransferRecord] {
    let cal = Calendar.current
    let now = Date.now
    func ago(_ days: Int) -> Date { cal.date(byAdding: .day, value: -days, to: now)! }

    return [
        // ── TODAY ─────────────────────────────────────────────────────────────
        TransferRecord(
            peerEmoji: "🐱", peerName: "Alice",
            date: now,
            direction: .sent, type: .text,
            detail: "Hey! Did you get the files?"
        ),
        TransferRecord(
            peerEmoji: "🦊", peerName: "Bob",
            date: now,
            direction: .received, type: .text,
            detail: "Sure! Everything looks great. I went through all the documents and they seem to be in order. Let me know if you need anything else — happy to help with the next batch whenever you're ready to send it over."
        ),
        TransferRecord(
            peerEmoji: "🐻", peerName: "Carol",
            date: now,
            direction: .received, type: .contact,
            detail: "Jane Smith"
        ),
        TransferRecord(
            peerEmoji: "🐱", peerName: "Alice",
            date: now,
            direction: .sent, type: .photo,
            detail: "photo_2024.jpg",
            attachmentURLs: [url("photo_2024.jpg")],
            fileBytes: 2_400_000
        ),
        TransferRecord(
            peers: [Peer(displayName: "🦊 Bob"), Peer(displayName: "🐻 Carol")],
            date: now,
            direction: .sent, type: .text,
            detail: "Hey both — here are the meeting notes from this morning!"
        ),
        TransferRecord(
            peers: [Peer(displayName: "🐼 Dave"), Peer(displayName: "🐱 Alice"), Peer(displayName: "🦊 Bob")],
            date: now,
            direction: .sent, type: .file,
            detail: "slides_final.pdf",
            attachmentURLs: [url("slides_final.pdf")],
            fileBytes: 4_100_000
        ),
        TransferRecord(
            peers: [
                Peer(displayName: "🐻 Carol"), Peer(displayName: "🐱 Alice"),
                Peer(displayName: "🦊 Bob"),   Peer(displayName: "🐼 Dave"),
            ],
            date: now,
            direction: .received, type: .text,
            detail: "Great, we're all synced up for the meeting!"
        ),
        // ── YESTERDAY ─────────────────────────────────────────────────────────
        TransferRecord(
            peerEmoji: "🦊", peerName: "Bob",
            date: ago(1),
            direction: .received, type: .photo,
            detail: "2 photos",
            attachmentURLs: [url("img1.jpg"), url("img2.jpg")],
            fileBytes: 5_100_000
        ),
        TransferRecord(
            peerEmoji: "🐻", peerName: "Carol",
            date: ago(1),
            direction: .sent, type: .file,
            detail: "2 documents",
            attachmentURLs: [url("report.pdf"), url("budget.xlsx")],
            fileBytes: 1_200_000
        ),
        TransferRecord(
            peerEmoji: "🐼", peerName: "Dave",
            date: ago(1),
            direction: .received, type: .file,
            detail: "3 documents",
            attachmentURLs: [url("deck.pptx"), url("notes.docx"), url("archive.zip")],
            fileBytes: 8_500_000
        ),
        TransferRecord(
            peerEmoji: "🐱", peerName: "Alice",
            date: ago(1),
            direction: .sent, type: .photo,
            detail: "3 photos",
            attachmentURLs: [url("a.jpg"), url("b.jpg"), url("c.jpg")],
            fileBytes: 8_700_000
        ),
        TransferRecord(
            peerEmoji: "🐻", peerName: "Carol",
            date: ago(1),
            direction: .received, type: .file,
            detail: "invoice_Q4.pdf",
            attachmentURLs: [url("invoice_Q4.pdf")],
            fileBytes: 340_000
        ),
        // ── This week ─────────────────────────────────────────────────────────
        TransferRecord(
            peerEmoji: "🦊", peerName: "Bob",
            date: ago(3),
            direction: .sent, type: .file,
            detail: "proposal_v3.docx",
            attachmentURLs: [url("proposal_v3.docx")],
            fileBytes: 120_000
        ),
        TransferRecord(
            peerEmoji: "🐼", peerName: "Dave",
            date: ago(3),
            direction: .received, type: .file,
            detail: "assets.zip",
            attachmentURLs: [url("assets.zip")],
            fileBytes: 45_800_000
        ),
        TransferRecord(
            peerEmoji: "🐼", peerName: "Dave",
            date: ago(4),
            direction: .sent, type: .file,
            detail: "presentation.pptx",
            attachmentURLs: [url("presentation.pptx")],
            fileBytes: 6_200_000
        ),
        // ── Older ─────────────────────────────────────────────────────────────
        TransferRecord(
            peerEmoji: "🐱", peerName: "Alice",
            date: ago(10),
            direction: .sent, type: .text,
            detail: "Here are the meeting notes from last Monday."
        ),
        TransferRecord(
            peerEmoji: "🐻", peerName: "Carol",
            date: ago(10),
            direction: .received, type: .photo,
            detail: "holiday_trip.jpg",
            attachmentURLs: [url("holiday_trip.jpg")],
            fileBytes: 3_900_000
        ),
    ]
}

// MARK: - Standalone list controller

private final class HistoryListPreviewController: UIViewController {

    private enum CellKind { case text, singleMedia, multiItem, document }

    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: makeLayout()
    )
    private var diffDataSource: UICollectionViewDiffableDataSource<String, UUID>!
    private let allRecords = records()
    private var byID: [UUID: TransferRecord] = [:]
    private let gate: any HistoryThumbnailGate = PreviewThumbnailGate()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        byID = Dictionary(uniqueKeysWithValues: allRecords.map { ($0.id, $0) })
        setupCollectionView()
        setupDataSource()
        applySnapshot()
    }

    private func setupCollectionView() {
        collectionView.backgroundColor = .systemBackground
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func makeLayout() -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.showsSeparators = false
        config.headerMode = .supplementary
        return UICollectionViewCompositionalLayout.list(using: config)
    }

    private func cellKind(for record: TransferRecord) -> CellKind {
        switch record.type {
        case .text, .contact, .document: return .text
        case .photo:
            switch record.attachmentURLs.count {
            case 0:    return .text
            case 1:    return .singleMedia
            default:   return .multiItem
            }
        case .file:
            switch record.attachmentURLs.count {
            case 0:    return .text
            case 1:    return .document
            default:   return .multiItem
            }
        }
    }

    private func setupDataSource() {
        let textReg = UICollectionView.CellRegistration<HistoryTextCell, UUID> { [weak self] cell, _, id in
            guard let record = self?.byID[id] else { return }
            cell.configure(with: record)
            cell.onSizeChange = { [weak cv = self?.collectionView] in
                UIView.animate(withDuration: 0.3) { cv?.performBatchUpdates(nil) }
            }
        }
        let imageReg = UICollectionView.CellRegistration<HistoryMediaCell, UUID> { [weak self] cell, _, id in
            guard let self, let record = byID[id] else { return }
            cell.configure(with: record, gate: gate)
        }
        let multiReg = UICollectionView.CellRegistration<HistoryMultiItemCell, UUID> { [weak self] cell, _, id in
            guard let self, let record = byID[id] else { return }
            cell.configure(with: record, gate: gate)
        }
        let docReg = UICollectionView.CellRegistration<HistoryDocumentCell, UUID> { [weak self] cell, _, id in
            guard let self, let record = byID[id] else { return }
            cell.configure(with: record, gate: gate)
        }
        let headerReg = UICollectionView.SupplementaryRegistration<HistorySectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, indexPath in
            guard let section = self?.diffDataSource?.sectionIdentifier(for: indexPath.section) else { return }
            header.configure(title: section)
        }

        diffDataSource = UICollectionViewDiffableDataSource<String, UUID>(
            collectionView: collectionView
        ) { [weak self] cv, indexPath, id in
            guard let self, let record = byID[id] else { return UICollectionViewCell() }
            switch cellKind(for: record) {
            case .text:
                return cv.dequeueConfiguredReusableCell(using: textReg, for: indexPath, item: id)
            case .singleMedia:
                return cv.dequeueConfiguredReusableCell(using: imageReg, for: indexPath, item: id)
            case .multiItem:
                return cv.dequeueConfiguredReusableCell(using: multiReg, for: indexPath, item: id)
            case .document:
                return cv.dequeueConfiguredReusableCell(using: docReg, for: indexPath, item: id)
            }
        }
        diffDataSource.supplementaryViewProvider = { cv, _, indexPath in
            cv.dequeueConfiguredReusableSupplementary(using: headerReg, for: indexPath)
        }
    }

    private func applySnapshot() {
        var orderedSections: [String] = []
        var groups: [String: [TransferRecord]] = [:]

        for record in allRecords.sorted(by: { $0.date > $1.date }) {
            let section = sectionTitle(for: record.date)
            if groups[section] == nil { orderedSections.append(section) }
            groups[section, default: []].append(record)
        }

        var snap = NSDiffableDataSourceSnapshot<String, UUID>()
        for section in orderedSections {
            snap.appendSections([section])
            snap.appendItems((groups[section] ?? []).map(\.id), toSection: section)
        }
        diffDataSource.apply(snap, animatingDifferences: false)
    }

    private func sectionTitle(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "TODAY" }
        if cal.isDateInYesterday(date) { return "YESTERDAY" }
        let weekAgo = cal.date(byAdding: .day, value: -7, to: .now) ?? .now
        if date > weekAgo { return date.formatted(.dateTime.weekday(.wide)).uppercased() }
        return date.formatted(.dateTime.month(.wide).day()).uppercased()
    }
}

// MARK: - SwiftUI preview

private struct HistoryListPreviewWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> HistoryListPreviewController {
        HistoryListPreviewController()
    }
    func updateUIViewController(_ vc: HistoryListPreviewController, context: Context) {}
}

#Preview("History — all cell types", traits: .fixedLayout(width: 390, height: 900)) {
    HistoryListPreviewWrapper()
}
#endif
