import UIKit

extension TransferCurtainViewController {

    // MARK: - Diffable data source

    func setupDataSource() {
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

    func applySnapshot() {
        var snap = NSDiffableDataSourceSnapshot<Int, UUID>()
        snap.appendSections([0])
        snap.appendItems(history.map(\.id))
        dataSource?.apply(snap, animatingDifferences: true)
        emptyLabel.isHidden = !history.isEmpty
    }

    func makeHistoryLayout() -> UICollectionViewLayout {
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
}
