import Foundation
import Observation

@Observable
@MainActor
final class SendFileUseCase {

    private(set) var outgoingTransfer: OutgoingFileTransfer?

    private let session: any NearbySessionService
    private let history: any TransferHistoryGate

    init(session: any NearbySessionService, history: any TransferHistoryGate) {
        self.session = session
        self.history = history
    }

    func send(_ urls: [URL], to peers: [Peer]) {
        guard !urls.isEmpty, !peers.isEmpty else { return }
        let total = urls.count
        let files = urls.enumerated().map { idx, url in
            FileToSend(url: url, name: url.lastPathComponent, index: idx, total: total)
        }
        outgoingTransfer = OutgoingFileTransfer(totalFiles: total, peerCount: peers.count)

        for peer in peers {
            session.sendFiles(files, to: peer) { [weak self] in
                self?.outgoingTransfer?.recordCompletion()
                if self?.outgoingTransfer?.isComplete == true {
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(for: .seconds(1.5))
                        self?.outgoingTransfer = nil
                    }
                }
            }
            let detail = total == 1 ? urls[0].lastPathComponent : "\(total) files"
            history.add(TransferRecord(
                peerEmoji: peer.emojiComponent,
                peerName: peer.nameComponent,
                direction: .sent,
                type: .file,
                detail: detail
            ))
        }
    }

    func abort() {
        outgoingTransfer = nil
    }
}
