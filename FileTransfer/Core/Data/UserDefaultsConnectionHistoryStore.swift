import Foundation

/// Persists connection history in `UserDefaults` as JSON-encoded `ConnectionRecord` array.
final class UserDefaultsConnectionHistoryStore: ConnectionHistoryStore {
    private let defaults: UserDefaults
    private let key = "ft.connectionHistory.records"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func hasConnected(to deviceID: UUID) -> Bool {
        allRecords().contains { $0.deviceID == deviceID }
    }

    func record(_ record: ConnectionRecord) {
        var records = allRecords()
        if let idx = records.firstIndex(where: { $0.deviceID == record.deviceID }) {
            records[idx] = record   // Update timestamp for existing peer
        } else {
            records.append(record)
        }
        save(records)
    }

    func allRecords() -> [ConnectionRecord] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ConnectionRecord].self, from: data)
        else { return [] }
        return decoded
    }

    private func save(_ records: [ConnectionRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: key)
        }
    }
}
