import Foundation

/// Non-persistent `ConnectionHistoryStore` for previews and unit tests.
/// Not intended for production use.
final class InMemoryConnectionHistoryStore: ConnectionHistoryStore {
    private var records: [ConnectionRecord] = []

    func hasConnected(to deviceID: UUID) -> Bool {
        records.contains { $0.deviceID == deviceID }
    }

    func record(_ record: ConnectionRecord) {
        if let idx = records.firstIndex(where: { $0.deviceID == record.deviceID }) {
            records[idx] = record
        } else {
            records.append(record)
        }
    }

    func allRecords() -> [ConnectionRecord] { records }
}
