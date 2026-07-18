import UIKit

extension TransferCurtainViewController {

    // MARK: - Detent math

    func computeDetents() {
        guard sheetView.bounds.height > 0 else { return }
        // Fixed layout constants avoid reading subview frames that may be 0
        // in early layout passes before Auto Layout resolves the full tree.
        //   grab area:        8 (top pad) + 5 (pill) + 8 (bottom pad) = 21
        //   selection row:   36 + 12 (gap below)                      = 48
        //   actions row:     80 + 14 (gap) + 1 (divider)              = 95
        //   history header:  historyHeaderHeight (44)
        let peek: CGFloat = 21 + 48 + 95 + historyHeaderHeight   // = 208
        expandedOffset = 0
        collapsedOffset = max(0, sheetView.bounds.height - peek)
    }

    func setOffset(_ offset: CGFloat, animated: Bool) {
        let clamped = max(expandedOffset, min(collapsedOffset, offset))
        currentOffset = clamped

        let ty = CGAffineTransform(translationX: 0, y: clamped)
        let range = collapsedOffset - expandedOffset
        let progress = range > 0 ? 1.0 - (clamped - expandedOffset) / range : 0.0
        let scrimAlpha = scrimEnabled ? CGFloat(progress) * 0.45 : 0

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

    func snapToDetent(velocity: CGFloat) {
        let mid = (collapsedOffset + expandedOffset) / 2
        let target: CGFloat
        if abs(velocity) > 500 {
            target = velocity > 0 ? collapsedOffset : expandedOffset
        } else {
            target = currentOffset < mid ? expandedOffset : collapsedOffset
        }
        setOffset(target, animated: true)
    }

    // MARK: - View hierarchy

    func buildViewHierarchy() {
        // Scrim — full-screen dimming behind the sheet
        scrimView.backgroundColor = .black
        scrimView.alpha = 0
        scrimView.isUserInteractionEnabled = false
        scrimView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrimView)

        // Sheet card
        sheetView.backgroundColor = .transferCurtainBackground
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
        textButton.addTarget(self,    action: #selector(textTapped),    for: .touchUpInside)
        photoButton.addTarget(self,   action: #selector(photoTapped),   for: .touchUpInside)
        fileButton.addTarget(self,    action: #selector(fileTapped),    for: .touchUpInside)
        contactButton.addTarget(self, action: #selector(contactTapped), for: .touchUpInside)

        // Contact sharing is suspended (see TransferFeatureFlags); omit its
        // button entirely when off so the remaining actions fill the row.
        let actionButtons: [UIView] = TransferFeatureFlags.contactSharing
            ? [contactButton, fileButton, photoButton, textButton]
            : [fileButton, photoButton, textButton]
        let actionsRow = UIStackView(arrangedSubviews: actionButtons)
        actionsRow.axis = .horizontal
        actionsRow.distribution = .fillEqually
        actionsRow.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(actionsRow)

        let divider = UIView()
        divider.backgroundColor = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(divider)

        // History section header — overlays the top of the collection view (see
        // below); brought back to front after the collection view is added so
        // it draws above scrolled content instead of being covered by it.
        historyHeaderView.translatesAutoresizingMaskIntoConstraints = false
        historyHeaderView.backgroundColor = .transferCurtainBackground
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

        // Collection view — anchored below the divider via collectionViewTopConstraint
        // (see its declaration), so history content starts in the same place
        // historyHeaderView occupies at rest. As the list scrolls, the sticky
        // section header rises to that same spot while historyHeaderView
        // fades out (see scrollViewDidScroll).
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        sheetView.addSubview(collectionView)
        sheetView.bringSubviewToFront(historyHeaderView)

        collectionViewTopConstraint = collectionView.topAnchor.constraint(
            equalTo: headerView.bottomAnchor, constant: historyHeaderHeight
        )

        // Empty state
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        sheetView.addSubview(emptyStateView)

        // Disabled-history banner, centred where the empty state sits (shown
        // only when history is off and there are no entries; when entries
        // exist the banner instead becomes the list's first element).
        disabledBanner.translatesAutoresizingMaskIntoConstraints = false
        disabledBanner.isHidden = true
        sheetView.addSubview(disabledBanner)

        NSLayoutConstraint.activate([
            // Scrim — full screen
            scrimView.topAnchor.constraint(equalTo: view.topAnchor),
            scrimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Sheet — below status bar, extends to screen bottom
            sheetView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            sheetView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Sheet horizontal placement: full-width on iPhone, centred+capped on iPad.
        if let maxWidth = maxSheetWidth {
            NSLayoutConstraint.activate([
                sheetView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                sheetView.widthAnchor.constraint(equalToConstant: maxWidth),
            ])
        } else {
            NSLayoutConstraint.activate([
                sheetView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                sheetView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])
        }

        NSLayoutConstraint.activate([
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

            // History section header — overlays the top of the collection view
            historyHeaderView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            historyHeaderView.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: 20),
            historyHeaderView.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor, constant: -20),
            historyHeaderView.heightAnchor.constraint(equalToConstant: historyHeaderHeight),
            historyTitle.leadingAnchor.constraint(equalTo: historyHeaderView.leadingAnchor),
            historyTitle.centerYAnchor.constraint(equalTo: historyHeaderView.centerYAnchor),
            hintLabel.trailingAnchor.constraint(equalTo: historyHeaderView.trailingAnchor),
            hintLabel.centerYAnchor.constraint(equalTo: historyHeaderView.centerYAnchor),
            hintLabel.leadingAnchor.constraint(greaterThanOrEqualTo: historyTitle.trailingAnchor, constant: 8),

            // Collection view: top constraint is collectionViewTopConstraint
            // (activated below), animated between historyHeaderHeight (rest)
            // and 0 (scrolled) — see collectionViewTopConstraint's doc comment.
            collectionViewTopConstraint,
            collectionView.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: sheetView.bottomAnchor),

            // Empty state
            emptyStateView.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyStateView.topAnchor.constraint(equalTo: collectionView.topAnchor, constant: 56),
            emptyStateView.widthAnchor.constraint(equalTo: collectionView.widthAnchor, constant: -48),

            // Disabled banner — centred near the top of the list area.
            disabledBanner.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            disabledBanner.topAnchor.constraint(equalTo: collectionView.topAnchor, constant: 24),
            disabledBanner.widthAnchor.constraint(equalTo: collectionView.widthAnchor, constant: -40),
        ])
    }
}
