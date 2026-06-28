import Foundation
import Observation

/// Orchestrates an outgoing media transfer: sends files to every connected peer,
/// tracks per-item completions, and auto-clears the transfer state after a brief
/// success window.
///
/// This is the first example of the Use Case layer — it replaces orchestration
/// that previously lived inside SearchViewModel.sendMedia() / abortMediaTransfer().
@Observable
@MainActor
final class SendMediaUseCase {

    private(set) var outgoingTransfer: OutgoingMediaTransfer?

    private let session: any NearbySessionService
    private let history: any TransferHistoryGate

    init(session: any NearbySessionService, history: any TransferHistoryGate) {
        self.session = session
        self.history = history
    }

    // MARK: - Intent

    func send(_ items: [MediaItem], to peers: [Peer]) {
        guard !items.isEmpty, !peers.isEmpty else { return }
        let fileURLs = items.map(\.fileURL)
        outgoingTransfer = OutgoingMediaTransfer(totalItems: fileURLs.count, peerCount: peers.count)

        for peer in peers {
            session.sendMedia(fileURLs: fileURLs, to: peer) { [weak self] in
                self?.outgoingTransfer?.recordCompletion()
                if self?.outgoingTransfer?.isComplete == true {
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(for: .seconds(1.5))
                        self?.outgoingTransfer = nil
                    }
                }
            }
            history.add(TransferRecord(
                peerEmoji: peer.emojiComponent,
                peerName: peer.nameComponent,
                direction: .sent,
                type: .photo,
                detail: "\(items.count) item\(items.count == 1 ? "" : "s")"
            ))
        }
    }

    /// Clears the outgoing transfer state. The caller is responsible for
    /// disconnecting peers if the transfer was aborted mid-flight.
    func abort() {
        outgoingTransfer = nil
    }
}
