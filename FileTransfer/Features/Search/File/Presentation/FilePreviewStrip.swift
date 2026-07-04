import SwiftUI
import UIKit

/// SwiftUI wrapper around a horizontal strip of DocumentCardView tiles.
/// Used inside ReceivedFileAlert to show rich file previews.
struct FilePreviewStrip: UIViewRepresentable {

    let files: [ReceivedFile]
    let gate: any HistoryThumbnailGate

    static func height(for count: Int) -> CGFloat {
        // Single: card (120) + gap (8) + filename label (~30) + padding (24) = 182
        // Multi:  card (120) + vertical padding (24) = 144
        count == 1 ? 182 : 144
    }

    func makeUIView(context: Context) -> FilePreviewStripUIView {
        FilePreviewStripUIView(files: files, gate: gate)
    }

    func updateUIView(_ uiView: FilePreviewStripUIView, context: Context) {}
}

// MARK: - UIKit backing view

final class FilePreviewStripUIView: UIView {

    private let files: [ReceivedFile]
    private let gate: any HistoryThumbnailGate
    private var cards: [DocumentCardView] = []

    private static let cardSize: CGFloat = 120
    private static let itemSpacing: CGFloat = 8
    private static let horizontalPadding: CGFloat = 16

    init(files: [ReceivedFile], gate: any HistoryThumbnailGate) {
        self.files = files
        self.gate = gate
        super.init(frame: .zero)
        // Leave translatesAutoresizingMaskIntoConstraints = true (default) so SwiftUI
        // can set the frame, giving internal constraints a valid width anchor.
        clipsToBounds = true
        if files.count == 1, let file = files.first {
            setupSingle(file)
        } else {
            setupStrip()
        }
        for card in cards { card.load(using: gate) }
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Single-file layout (wide card + filename label)

    private func setupSingle(_ file: ReceivedFile) {
        let card = DocumentCardView(url: file.url, index: 0, cornerRadius: 10)
        cards.append(card)

        let nameLabel = makeNameLabel(file.name)

        addSubview(card)
        addSubview(nameLabel)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalPadding),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontalPadding),
            card.heightAnchor.constraint(equalToConstant: Self.cardSize),

            nameLabel.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            nameLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12),
        ])
    }

    // MARK: - Multi-file horizontal scroll (matches HistoryMultiItemCell pattern)

    private func setupStrip() {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.clipsToBounds = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.contentInset = UIEdgeInsets(
            top: 0,
            left: Self.horizontalPadding,
            bottom: 0,
            right: Self.horizontalPadding
        )
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Self.itemSpacing
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])

        for (idx, file) in files.enumerated() {
            let card = DocumentCardView(url: file.url, index: idx, cornerRadius: 8)
            card.widthAnchor.constraint(equalToConstant: Self.cardSize).isActive = true
            cards.append(card)
            stack.addArrangedSubview(card)
        }
    }

    // MARK: - Helpers

    private func makeNameLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 12)
        l.textColor = .secondaryLabel
        l.numberOfLines = 2
        l.lineBreakMode = .byTruncatingMiddle
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }
}
