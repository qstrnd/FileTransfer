import QuickLook
import UIKit

extension TransferCurtainViewController {

    // MARK: - Cell type dispatch

    enum HistoryCellType {
        case text, singleMedia, multiMedia, document
    }

    func cellType(for record: TransferRecord) -> HistoryCellType {
        switch record.type {
        case .text, .contact, .document:
            return .text
        case .photo:
            switch record.attachmentURLs.count {
            case 0:    return .text
            case 1:    return .singleMedia
            default:   return .multiMedia
            }
        case .file:
            return .document
        }
    }

    // MARK: - Diffable data source

    func setupDataSource() {
        // Cell registrations
        let textReg = UICollectionView.CellRegistration<HistoryTextCell, UUID> { [weak self] cell, _, id in
            guard let record = self?.recordsByID[id] else { return }
            cell.configure(with: record)
            cell.onSizeChange = { [weak cv = self?.collectionView] in
                UIView.animate(withDuration: 0.3) { cv?.performBatchUpdates(nil) }
            }
        }

        let imageReg = UICollectionView.CellRegistration<HistoryMediaCell, UUID> { [weak self] cell, _, id in
            guard let self, let record = recordsByID[id] else { return }
            cell.configure(with: record, gate: thumbnailGate ?? HistoryThumbnailService())
        }

        let multiReg = UICollectionView.CellRegistration<HistoryMultiMediaCell, UUID> { [weak self] cell, _, id in
            guard let self, let record = recordsByID[id] else { return }
            cell.configure(with: record, gate: thumbnailGate ?? HistoryThumbnailService())
            cell.onThumbnailTap = { [weak self] index in
                guard let self else { return }
                currentPreviewURLs = record.attachmentURLs
                let ql = QLPreviewController()
                ql.dataSource = self
                ql.currentPreviewItemIndex = index
                present(ql, animated: true)
            }
        }

        let docReg = UICollectionView.CellRegistration<HistoryDocumentCell, UUID> { [weak self] cell, _, id in
            guard let self, let record = recordsByID[id] else { return }
            cell.configure(with: record, gate: thumbnailGate ?? HistoryThumbnailService())
        }

        // Section header registration
        let headerReg = UICollectionView.SupplementaryRegistration<HistorySectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, indexPath in
            guard let section = self?.dataSource?.sectionIdentifier(for: indexPath.section) else { return }
            header.configure(title: section)
        }

        dataSource = UICollectionViewDiffableDataSource<String, UUID>(
            collectionView: collectionView
        ) { [weak self] cv, indexPath, id in
            guard let self, let record = recordsByID[id] else { return UICollectionViewCell() }
            switch cellType(for: record) {
            case .text:
                return cv.dequeueConfiguredReusableCell(using: textReg, for: indexPath, item: id)
            case .singleMedia:
                return cv.dequeueConfiguredReusableCell(using: imageReg, for: indexPath, item: id)
            case .multiMedia:
                return cv.dequeueConfiguredReusableCell(using: multiReg, for: indexPath, item: id)
            case .document:
                return cv.dequeueConfiguredReusableCell(using: docReg, for: indexPath, item: id)
            }
        }

        dataSource?.supplementaryViewProvider = { cv, _, indexPath in
            cv.dequeueConfiguredReusableSupplementary(using: headerReg, for: indexPath)
        }

        collectionView.delegate = self
        collectionView.prefetchDataSource = self
    }

    func applySnapshot() {
        guard let dataSource else { return }
        var snap = NSDiffableDataSourceSnapshot<String, UUID>()

        for (section, records) in groupedBySection(history) {
            snap.appendSections([section])
            snap.appendItems(records.map(\.id), toSection: section)
        }

        dataSource.apply(snap, animatingDifferences: true)
        emptyLabel.isHidden = !history.isEmpty
    }

    func makeHistoryLayout() -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.showsSeparators = false
        config.headerMode = .supplementary
        config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self,
                  let id = dataSource?.itemIdentifier(for: indexPath) else { return nil }
            let action = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
                self?.onDeleteRecord?(id)
                completion(true)
            }
            action.image = UIImage(systemName: "trash")
            return UISwipeActionsConfiguration(actions: [action])
        }
        return UICollectionViewCompositionalLayout.list(using: config)
    }

    // MARK: - Section grouping

    private func groupedBySection(_ records: [TransferRecord]) -> [(String, [TransferRecord])] {
        var orderedSections: [String] = []
        var groups: [String: [TransferRecord]] = [:]

        for record in records.sorted(by: { $0.date > $1.date }) {
            let section = sectionTitle(for: record.date)
            if groups[section] == nil { orderedSections.append(section) }
            groups[section, default: []].append(record)
        }
        return orderedSections.map { ($0, groups[$0]!) }
    }

    private func sectionTitle(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "TODAY" }
        if cal.isDateInYesterday(date) { return "YESTERDAY" }
        let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: .now) ?? .now
        if date > sevenDaysAgo {
            return date.formatted(.dateTime.weekday(.wide)).uppercased()
        }
        return date.formatted(.dateTime.month(.wide).day()).uppercased()
    }
}

// MARK: - UICollectionViewDelegate (tap → QuickLook)

extension TransferCurtainViewController: UICollectionViewDelegate {

    func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        cv.deselectItem(at: indexPath, animated: true)
        guard let id = dataSource?.itemIdentifier(for: indexPath),
              let record = recordsByID[id],
              !record.attachmentURLs.isEmpty else { return }
        currentPreviewURLs = record.attachmentURLs
        let ql = QLPreviewController()
        ql.dataSource = self
        present(ql, animated: true)
    }
}

// MARK: - QLPreviewControllerDataSource

extension TransferCurtainViewController: QLPreviewControllerDataSource {

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        currentPreviewURLs.count
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        currentPreviewURLs[index] as NSURL
    }
}

// MARK: - UICollectionViewDataSourcePrefetching

extension TransferCurtainViewController: UICollectionViewDataSourcePrefetching {

    func collectionView(_ cv: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        guard let gate = thumbnailGate else { return }
        let urls = indexPaths
            .compactMap { dataSource?.itemIdentifier(for: $0) }
            .compactMap { recordsByID[$0] }
            .flatMap(\.attachmentURLs)
        gate.prefetch(urls)
    }
}
