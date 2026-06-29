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
        //   history header:  44
        let peek: CGFloat = 21 + 48 + 95 + 44   // = 208
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
        textButton.addTarget(self,    action: #selector(textTapped),    for: .touchUpInside)
        photoButton.addTarget(self,   action: #selector(photoTapped),   for: .touchUpInside)
        fileButton.addTarget(self,    action: #selector(fileTapped),    for: .touchUpInside)
        contactButton.addTarget(self, action: #selector(contactTapped), for: .touchUpInside)

        let actionsRow = UIStackView(arrangedSubviews: [contactButton, fileButton, photoButton, textButton])
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
