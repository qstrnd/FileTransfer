import SwiftData
import Foundation

@Observable
final class TransferHistoryStore: TransferHistoryGate {
    private(set) var records: [TransferRecord] = []
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        loadAll()
    }

    func add(_ record: TransferRecord) {
        context.insert(TransferItem(from: record))
        try? context.save()
        records.insert(record, at: 0)
    }

    func delete(_ id: UUID) {
        records.removeAll { $0.id == id }
        let descriptor = FetchDescriptor<TransferItem>()
        if let items = try? context.fetch(descriptor),
           let item = items.first(where: { $0.id == id }) {
            context.delete(item)
            try? context.save()
        }
    }

    private func loadAll() {
        let descriptor = FetchDescriptor<TransferItem>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        records = (try? context.fetch(descriptor))?.map(\.asRecord) ?? []
    }
}

#if DEBUG
extension TransferHistoryStore {
    static var preview: TransferHistoryStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: TransferItem.self, configurations: config)
        return TransferHistoryStore(context: ModelContext(container))
    }
}
#endif
