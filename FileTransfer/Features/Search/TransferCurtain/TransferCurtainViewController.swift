import UIKit

// Passes touches through to underlying views when they land on the
// transparent root background rather than on the sheet or its subviews.
final class PassthroughView: UIView {
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

    var onShareText:      (() -> Void)?
    var onSharePhoto:     (() -> Void)?
    var onShareFile:      (() -> Void)?
    var onShareContact:   (() -> Void)?
    var onClearSelection: (() -> Void)?

    // MARK: - Model state

    private(set) var selectedCount: Int = 0
    private(set) var history: [TransferRecord] = []
    private(set) var recordsByID: [UUID: TransferRecord] = [:]

    // MARK: - Detent state

    var collapsedOffset: CGFloat = 0
    var expandedOffset: CGFloat = 0
    var currentOffset: CGFloat = 0

    // MARK: - Views

    let scrimView = UIView()
    let sheetView = UIView()
    let countLabel = UILabel()
    let clearButton = UIButton(type: .system)
    let textButton = TransferActionButton(
        icon: TransferType.text.systemImage, title: "Text",
        normalBG: TransferType.text.normalBG, pressedBG: TransferType.text.pressedBG,
        iconTint: TransferType.text.tintColor
    )
    let photoButton = TransferActionButton(
        icon: TransferType.photo.systemImage, title: "Gallery",
        normalBG: TransferType.photo.normalBG, pressedBG: TransferType.photo.pressedBG,
        iconTint: TransferType.photo.tintColor
    )
    let fileButton = TransferActionButton(
        icon: TransferType.file.systemImage, title: "File",
        normalBG: TransferType.file.normalBG, pressedBG: TransferType.file.pressedBG,
        iconTint: TransferType.file.tintColor
    )
    let contactButton = TransferActionButton(
        icon: TransferType.contact.systemImage, title: "Contact",
        normalBG: TransferType.contact.normalBG, pressedBG: TransferType.contact.pressedBG,
        iconTint: TransferType.contact.tintColor
    )
    let headerView = UIView()
    let historyHeaderView = UIView()
    let historyHeaderHeight: CGFloat = 44
    let hintLabel = UILabel()
    let emptyStateView = HistoryEmptyStateView()
    /// Shown centred when history is disabled and there are no entries.
    let disabledBanner = HistoryDisabledBannerPill()
    private(set) lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: makeHistoryLayout()
    )

    var dataSource: UICollectionViewDiffableDataSource<String, UUID>?
    /// Top-space between the divider and the collection view. Animated from
    /// `historyHeaderHeight` (rest) to 0 (scrolled) so the already-pinned
    /// section header — which clamps to the collection view's own frame, not
    /// its content inset — slides up to the divider in lockstep with the
    /// frame instead of sitting at a permanent inset-sized gap.
    var collectionViewTopConstraint: NSLayoutConstraint!

    var thumbnailGate: (any HistoryThumbnailGate)?
    var onDeleteRecord: ((UUID) -> Void)?
    var currentPreviewURLs: [URL] = []

    /// True when history recording is turned off; drives the disabled banner.
    private(set) var isHistoryDisabled = false
    /// Whether the list currently includes the disabled banner as a global header,
    /// so the layout is only rebuilt when that actually changes.
    var isShowingListBanner = false

    // MARK: - Pan gesture state

    var panStartY: CGFloat = 0
    var panStartOffset: CGFloat = 0
    var panVelocity: CGFloat = 0
    var hasSnappedInitially = false

    // MARK: - History header overlay state

    var isHistoryHeaderHidden = false

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
        computeDetents()
    }

    // MARK: - Public API

    func update(selectedCount: Int) {
        guard selectedCount != self.selectedCount else { return }
        self.selectedCount = selectedCount
        updateSelectionUI()
    }

    func update(historyDisabled: Bool) {
        guard historyDisabled != isHistoryDisabled else { return }
        isHistoryDisabled = historyDisabled
        refreshBannerLayoutIfNeeded()
        updateDisabledUI()
    }

    func update(history: [TransferRecord]) {
        self.history = history
        recordsByID = Dictionary(uniqueKeysWithValues: history.map { ($0.id, $0) })
        applySnapshot()
    }

    var scrimEnabled = true
    /// Set before viewDidLoad to constrain the sheet to a centred fixed width.
    /// Nil (default) makes the sheet span the full view width, matching iPhone portrait.
    var maxSheetWidth: CGFloat?

    func setScrimEnabled(_ enabled: Bool) {
        scrimEnabled = enabled
        if !enabled { scrimView.alpha = 0 }
    }

    // MARK: - Selection UI

    func updateSelectionUI() {
        if selectedCount == 0 {
            countLabel.text = "Select a device"
            countLabel.textColor = .secondaryLabel
        } else {
            countLabel.text = selectedCount == 1 ? "1 device connected" : "\(selectedCount) devices connected"
            countLabel.textColor = .label
        }
        let enabled = selectedCount > 0
        clearButton.isHidden = !enabled
        [textButton, photoButton, fileButton, contactButton].forEach { $0.isEnabled = enabled }
    }

    // MARK: - Button actions

    @objc func clearTapped()  { onClearSelection?() }
    @objc func textTapped()   { onShareText?() }
    @objc func photoTapped()  { onSharePhoto?() }
    @objc func fileTapped()   { onShareFile?() }
    @objc func contactTapped(){ onShareContact?() }
}
