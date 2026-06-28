import Foundation

/// Port for appending records to the transfer history store.
/// Read access is intentionally excluded — the @Observable concrete store
/// is observed directly by Presentation for live UI updates.
protocol TransferHistoryGate {
    func add(_ record: TransferRecord)
}
