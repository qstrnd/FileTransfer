import Foundation
import Observation

@Observable
@MainActor
final class SendFileUseCase {

    private(set) var outgoingTransfer: OutgoingFileTransfer?

    private let session: any NearbySessionService
    private let history: any TransferHistoryGate
    private let attachmentCache: any AttachmentCacheGate
    private var progressPollingTask: Task<Void, Never>?
    private var activeProgresses: [Progress] = []

    init(
        session: any NearbySessionService,
        history: any TransferHistoryGate,
        attachmentCache: any AttachmentCacheGate
    ) {
        self.session = session
        self.history = history
        self.attachmentCache = attachmentCache
    }

    func send(_ urls: [URL], to peers: [Peer]) {
        guard !urls.isEmpty, !peers.isEmpty else { return }
        let total = urls.count
        let files = urls.enumerated().map { idx, url in
            FileToSend(url: url, name: url.lastPathComponent, index: idx, total: total)
        }
        outgoingTransfer = OutgoingFileTransfer(totalFiles: total, peerCount: peers.count)
        activeProgresses = []
        startProgressPolling()

        let srcURLs = urls
        let totalBytes = attachmentCache.fileBytes(for: srcURLs)
        let detail = total == 1 ? urls[0].lastPathComponent : "\(total) files"

        for peer in peers {
            let recordID = UUID()
            let progresses = session.sendFiles(files, to: peer) { [weak self] in
                self?.outgoingTransfer?.recordCompletion()
                if self?.outgoingTransfer?.isComplete == true {
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(for: .seconds(1.5))
                        self?.outgoingTransfer = nil
                    }
                }
            }
            activeProgresses.append(contentsOf: progresses)

            Task { @MainActor [weak self] in
                guard let self else { return }
                let cachedURLs = await attachmentCache.cache(srcURLs, forRecord: recordID)
                history.add(TransferRecord(
                    id: recordID,
                    peerEmoji: peer.emojiComponent,
                    peerName: peer.nameComponent,
                    direction: .sent,
                    type: .file,
                    detail: detail,
                    attachmentURLs: cachedURLs,
                    fileBytes: totalBytes > 0 ? totalBytes : nil
                ))
            }
        }
    }

    func abort() {
        progressPollingTask?.cancel()
        progressPollingTask = nil
        activeProgresses = []
        outgoingTransfer = nil
    }

    // MARK: - Private

    private func startProgressPolling() {
        progressPollingTask?.cancel()
        progressPollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard let self, outgoingTransfer != nil else { break }
                let progresses = activeProgresses
                guard !progresses.isEmpty else { continue }
                let total = progresses.reduce(0.0) { $0 + Double($1.totalUnitCount) }
                let completed = progresses.reduce(0.0) { $0 + Double($1.completedUnitCount) }
                if total > 0 {
                    outgoingTransfer?.progress = completed / total
                }
                if outgoingTransfer?.isComplete == true { break }
            }
        }
    }
}
