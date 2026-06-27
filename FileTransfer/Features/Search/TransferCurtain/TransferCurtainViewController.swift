import UIKit

// Passes touches through to underlying views when they land on the
// transparent root background rather than on the sheet or its subviews.
private final class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}

/// Two-detent bottom sheet presenting share actions and transfer history.
///
/// Collapsed detent: shows grab handle, selection count, action buttons, and
/// a peek of the history list. Expanded detent: slides up to reveal the full
/// history while the peer discovery view scales back behind the scrim.
///
/// The sheet is driven by a UIPanGestureRecognizer restricted to the grab/header
/// area so it doesn't conflict with UICollectionView scroll gestures.
final class TransferCurtainViewController: UIViewController {

    // MARK: - Callbacks (set by the UIViewControllerRepresentable on each update)

    var onShareText:     (() -> Void)?
    var onSharePhoto:    (() -> Void)?
    var onShareDocument: (() -> Void)?
    var onShareContact:  (() -> Void)?
    var onClearSelection: (() -> Void)?

    // MARK: - Model state

    private var selectedCount: Int = 0
    private var history: [TransferRecord] = []
    private var recordsByID: [UUID: TransferRecord] = [:]

    // MARK: - Detent

    private var collapsedOffset: CGFloat = 0  // translateY when peeking
    private var expandedOffset: CGFloat = 0   // translateY when fully open (= 0)
    private var currentOffset: CGFloat = 0

    // MARK: - Views

    private let scrimView = UIView()
    private let sheetView = UIView()
    private let countLabel = UILabel()
    private let clearButton = UIButton(type: .system)
    private let textButton     = TransferActionButton(
        icon: "bubble.left", title: "Text",
        normalBG: TransferType.text.normalBG, pressedBG: TransferType.text.pressedBG,
        iconTint: TransferType.text.tintColor
    )
    private let photoButton    = TransferActionButton(
        icon: "photo.stack", title: "Gallery",
        normalBG: TransferType.photo.normalBG, pressedBG: TransferType.photo.pressedBG,
        iconTint: TransferType.photo.tintColor
    )
    private let documentButton = TransferActionButton(
        icon: "doc", title: "Document",
        normalBG: TransferType.document.normalBG, pressedBG: TransferType.document.pressedBG,
        iconTint: TransferType.document.tintColor
    )
    private let contactButton  = TransferActionButton(
        icon: "person", title: "Contact",
        normalBG: TransferType.contact.normalBG, pressedBG: TransferType.contact.pressedBG,
        iconTint: TransferType.contact.tintColor
    )
    private let headerView = UIView()
    private let historyHeaderView = UIView()
    private let hintLabel = UILabel()
    private let emptyLabel = UILabel()
    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: makeHistoryLayout()
    )

    private var dataSource: UICollectionViewDiffableDataSource<Int, UUID>!
    private var panStartY: CGFloat = 0
    private var panStartOffset: CGFloat = 0
    private var panVelocity: CGFloat = 0
    private var hasSnappedInitially = false

    // MARK: - Lifecycle

    override func loadView() {
        view = PassthroughView()
        view.backgroundColor = .clear
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildViewHierarchy()
        setupDataSource()
        setupPanGesture()
        updateSelectionUI()
        applySnapshot()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        computeDetents()
        guard !hasSnappedInitially, collapsedOffset > 0 else { return }
        hasSnappedInitially = true
        // Defer one run loop so SwiftUI finishes all pending layout passes before
        // we position the sheet. Without this, the sheet snaps to a stale frame.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.computeDetents()
            self.setOffset(self.collapsedOffset, animated: false)
        }
    }

    override var prefersHomeIndicatorAutoHidden: Bool { false }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        let sb = view.safeAreaInsets.bottom
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: sb + 20, right: 0)
        // Re-run detents: the bottom safe area is now part of the peek calculation.
        computeDetents()
    }

    // MARK: - Public API

    func update(selectedCount: Int) {
        guard selectedCount != self.selectedCount else { return }
        self.selectedCount = selectedCount
        updateSelectionUI()
    }

    func update(history: [TransferRecord]) {
        self.history = history
        recordsByID = Dictionary(uniqueKeysWithValues: history.map { ($0.id, $0) })
        applySnapshot()
    }

    // MARK: - Detent math

    private func computeDetents() {
        // Use bounds (not frame) — a pending transform doesn't affect bounds.height.
        guard sheetView.bounds.height > 0 else { return }
        // Fixed layout constants avoid reading subview frames that may be 0
        // in early layout passes before Auto Layout resolves the full tree.
        //   grab area:        8 (top pad) + 5 (pill) + 8 (bottom pad) = 21
        //   selection row:   36 + 12 (gap below)                      = 48
        //   actions row:     80 + 14 (gap) + 1 (divider)              = 95
        //   history header:  44
        let peek: CGFloat = 21 + 48 + 95 + 44   // = 208
        expandedOffset = 0
        collapsedOffset = max(0, sheetView.bounds.height - peek)
    }

    private func setOffset(_ offset: CGFloat, animated: Bool) {
        let clamped = max(expandedOffset, min(collapsedOffset, offset))
        currentOffset = clamped

        let ty = CGAffineTransform(translationX: 0, y: clamped)
        let range = collapsedOffset - expandedOffset
        let progress = range > 0 ? 1.0 - (clamped - expandedOffset) / range : 0.0
        let scrimAlpha = CGFloat(progress) * 0.45

        if animated {
            let params = UISpringTimingParameters(dampingRatio: 0.78, initialVelocity: .zero)
            let anim = UIViewPropertyAnimator(duration: 0.5, timingParameters: params)
            anim.addAnimations {
                self.sheetView.transform = ty
                self.scrimView.alpha = scrimAlpha
            }
            anim.startAnimation()
        } else {
            sheetView.transform = ty
            scrimView.alpha = scrimAlpha
        }

        hintLabel.isHidden = progress > 0.5
    }

    private func snapToDetent(velocity: CGFloat) {
        let mid = (collapsedOffset + expandedOffset) / 2
        let target: CGFloat
        if abs(velocity) > 500 {
            target = velocity > 0 ? collapsedOffset : expandedOffset
        } else {
            target = currentOffset < mid ? expandedOffset : collapsedOffset
        }
        setOffset(target, animated: true)
    }

    // MARK: - Pan gesture

    private func setupPanGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        sheetView.addGestureRecognizer(pan)
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let y = pan.location(in: view).y
        switch pan.state {
        case .began:
            panStartY = y
            panStartOffset = currentOffset
        case .changed:
            panVelocity = pan.velocity(in: view).y
            setOffset(panStartOffset + (y - panStartY), animated: false)
        case .ended, .cancelled:
            snapToDetent(velocity: panVelocity)
        default:
            break
        }
    }

    // MARK: - Diffable data source

    private func setupDataSource() {
        let registration = UICollectionView.CellRegistration<TransferHistoryCell, UUID> { [weak self] cell, _, id in
            guard let record = self?.recordsByID[id] else { return }
            cell.configure(with: record)
        }

        dataSource = UICollectionViewDiffableDataSource<Int, UUID>(
            collectionView: collectionView
        ) { cv, indexPath, id in
            cv.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: id)
        }
    }

    private func applySnapshot() {
        var snap = NSDiffableDataSourceSnapshot<Int, UUID>()
        snap.appendSections([0])
        snap.appendItems(history.map(\.id))
        dataSource?.apply(snap, animatingDifferences: true)
        emptyLabel.isHidden = !history.isEmpty
    }

    private func makeHistoryLayout() -> UICollectionViewLayout {
        // Estimated height allows cells to self-size; future cells with image or
        // document previews will naturally grow taller without layout changes.
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(72)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(72)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        return UICollectionViewCompositionalLayout(section: NSCollectionLayoutSection(group: group))
    }

    // MARK: - Selection UI

    private func updateSelectionUI() {
        if selectedCount == 0 {
            countLabel.text = "Select a device"
            countLabel.textColor = .secondaryLabel
        } else {
            countLabel.text = selectedCount == 1 ? "1 device connected" : "\(selectedCount) devices connected"
            countLabel.textColor = .label
        }
        let enabled = selectedCount > 0
        clearButton.isHidden = !enabled
        [textButton, photoButton, documentButton, contactButton].forEach { $0.isEnabled = enabled }
    }

    // MARK: - Button actions

    @objc private func clearTapped()    { onClearSelection?() }
    @objc private func textTapped()     { onShareText?() }
    @objc private func photoTapped()    { onSharePhoto?() }
    @objc private func documentTapped() { onShareDocument?() }
    @objc private func contactTapped()  { onShareContact?() }

    // MARK: - View hierarchy

    private func buildViewHierarchy() {
        // Scrim — full-screen dimming behind the sheet
        scrimView.backgroundColor = .black
        scrimView.alpha = 0
        scrimView.isUserInteractionEnabled = false
        scrimView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrimView)

        // Sheet card
        sheetView.backgroundColor = .systemBackground
        sheetView.layer.cornerRadius = 22
        sheetView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheetView.layer.shadowColor = UIColor.black.cgColor
        sheetView.layer.shadowOpacity = 0.10
        sheetView.layer.shadowOffset = CGSize(width: 0, height: -2)
        sheetView.layer.shadowRadius = 12
        sheetView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sheetView)

        // Grab pill
        let grabPill = UIView()
        grabPill.backgroundColor = .systemFill
        grabPill.layer.cornerRadius = 2.5
        grabPill.translatesAutoresizingMaskIntoConstraints = false
        sheetView.addSubview(grabPill)

        // Header container
        headerView.translatesAutoresizingMaskIntoConstraints = false
        sheetView.addSubview(headerView)

        // Selection row
        countLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        clearButton.setTitle("Disconnect All", for: .normal)
        clearButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)

        let selRow = UIView()
        selRow.translatesAutoresizingMaskIntoConstraints = false
        selRow.addSubview(countLabel)
        selRow.addSubview(clearButton)
        headerView.addSubview(selRow)

        // Action buttons row
        textButton.addTarget(self,     action: #selector(textTapped),     for: .touchUpInside)
        photoButton.addTarget(self,    action: #selector(photoTapped),    for: .touchUpInside)
        documentButton.addTarget(self, action: #selector(documentTapped), for: .touchUpInside)
        contactButton.addTarget(self,  action: #selector(contactTapped),  for: .touchUpInside)

        let actionsRow = UIStackView(arrangedSubviews: [contactButton, documentButton, photoButton, textButton])
        actionsRow.axis = .horizontal
        actionsRow.distribution = .fillEqually
        actionsRow.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(actionsRow)

        let divider = UIView()
        divider.backgroundColor = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(divider)

        // History section header
        historyHeaderView.translatesAutoresizingMaskIntoConstraints = false
        sheetView.addSubview(historyHeaderView)

        let historyTitle = UILabel()
        historyTitle.text = "RECENT TRANSFERS"
        historyTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        historyTitle.textColor = .secondaryLabel
        historyTitle.translatesAutoresizingMaskIntoConstraints = false
        historyHeaderView.addSubview(historyTitle)

        hintLabel.text = "Drag up for full history"
        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.textColor = .secondaryLabel
        hintLabel.textAlignment = .right
        hintLabel.setContentHuggingPriority(.required, for: .horizontal)
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        historyHeaderView.addSubview(hintLabel)

        // Collection view
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        sheetView.addSubview(collectionView)

        // Empty state
        emptyLabel.text = "No transfers yet.\nPick someone and send something."
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.font = .systemFont(ofSize: 14)
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        sheetView.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            // Scrim — full screen
            scrimView.topAnchor.constraint(equalTo: view.topAnchor),
            scrimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Sheet — below status bar, full width, extends to screen bottom
            sheetView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            sheetView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sheetView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Grab pill: centered at top of sheet
            grabPill.centerXAnchor.constraint(equalTo: sheetView.centerXAnchor),
            grabPill.topAnchor.constraint(equalTo: sheetView.topAnchor, constant: 8),
            grabPill.widthAnchor.constraint(equalToConstant: 38),
            grabPill.heightAnchor.constraint(equalToConstant: 5),

            // Header view
            headerView.topAnchor.constraint(equalTo: grabPill.bottomAnchor, constant: 8),
            headerView.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor, constant: -20),

            // Selection row
            selRow.topAnchor.constraint(equalTo: headerView.topAnchor),
            selRow.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            selRow.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            selRow.heightAnchor.constraint(equalToConstant: 36),
            countLabel.leadingAnchor.constraint(equalTo: selRow.leadingAnchor),
            countLabel.centerYAnchor.constraint(equalTo: selRow.centerYAnchor),
            clearButton.trailingAnchor.constraint(equalTo: selRow.trailingAnchor),
            clearButton.centerYAnchor.constraint(equalTo: selRow.centerYAnchor),

            // Actions row
            actionsRow.topAnchor.constraint(equalTo: selRow.bottomAnchor, constant: 12),
            actionsRow.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            actionsRow.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            actionsRow.heightAnchor.constraint(equalToConstant: 80),

            // Divider below actions
            divider.topAnchor.constraint(equalTo: actionsRow.bottomAnchor, constant: 14),
            divider.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5),
            divider.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),

            // History section header
            historyHeaderView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            historyHeaderView.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: 20),
            historyHeaderView.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor, constant: -20),
            historyHeaderView.heightAnchor.constraint(equalToConstant: 44),
            historyTitle.leadingAnchor.constraint(equalTo: historyHeaderView.leadingAnchor),
            historyTitle.centerYAnchor.constraint(equalTo: historyHeaderView.centerYAnchor),
            hintLabel.trailingAnchor.constraint(equalTo: historyHeaderView.trailingAnchor),
            hintLabel.centerYAnchor.constraint(equalTo: historyHeaderView.centerYAnchor),
            hintLabel.leadingAnchor.constraint(greaterThanOrEqualTo: historyTitle.trailingAnchor, constant: 8),

            // Collection view fills the rest of the sheet
            collectionView.topAnchor.constraint(equalTo: historyHeaderView.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: sheetView.bottomAnchor),

            // Empty state label
            emptyLabel.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyLabel.topAnchor.constraint(equalTo: collectionView.topAnchor, constant: 42),
            emptyLabel.widthAnchor.constraint(equalTo: collectionView.widthAnchor, constant: -48),
        ])
    }
}

// MARK: - UIGestureRecognizerDelegate

extension TransferCurtainViewController: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer is UIPanGestureRecognizer else { return true }
        // Only begin pan when the touch originates in the grab pill / header area.
        let point = gestureRecognizer.location(in: sheetView)
        return point.y <= headerView.frame.maxY + 10
    }
}
