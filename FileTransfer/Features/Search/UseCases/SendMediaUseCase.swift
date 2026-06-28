import Foundation
import Observation

/// Orchestrates an outgoing media transfer: flattens MediaItems (including Live Photo
/// pairs) into a file list, sends to every connected peer, tracks per-file completions,
/// and auto-clears the transfer state after a brief success window.
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

        let logicalTotal = items.count
        var files: [MediaFileToSend] = []
        for (idx, item) in items.enumerated() {
            if let lpVideoURL = item.livePhotoVideoURL {
                // Live Photo: send the still first, then the companion video.
                files.append(MediaFileToSend(
                    url: item.fileURL, logicalIndex: idx, logicalTotal: logicalTotal,
                    kind: .livePhotoStill, suggestedName: item.fileName
                ))
                files.append(MediaFileToSend(
                    url: lpVideoURL, logicalIndex: idx, logicalTotal: logicalTotal,
                    kind: .livePhotoVideo, suggestedName: nil
                ))
            } else {
                files.append(MediaFileToSend(
                    url: item.fileURL, logicalIndex: idx, logicalTotal: logicalTotal,
                    kind: .regular, suggestedName: item.fileName
                ))
            }
        }

        // OutgoingMediaTransfer counts actual files (including LP companions).
        outgoingTransfer = OutgoingMediaTransfer(totalItems: files.count, peerCount: peers.count)

        for peer in peers {
            session.sendMedia(files, to: peer) { [weak self] in
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
