import Foundation
import Observation
import OSLog

private let log = Logger(subsystem: "com.qstrnd.FileTransfer", category: "SendMedia")

/// Orchestrates an outgoing media transfer: flattens MediaItems (including Live Photo
/// pairs) into a file list, sends to every connected peer, tracks per-file completions,
/// caches attachment copies for history, and auto-clears state after a success window.
@Observable
@MainActor
final class SendMediaUseCase {

    private(set) var outgoingTransfer: OutgoingMediaTransfer?

    private let session: any NearbySessionService
    private let history: any TransferHistoryGate
    private let attachmentCache: any AttachmentCacheGate
    private let haptics: any HapticsGate
    private var progressPollingTask: Task<Void, Never>?
    private var activeProgresses: [Progress] = []

    init(
        session: any NearbySessionService,
        history: any TransferHistoryGate,
        attachmentCache: any AttachmentCacheGate,
        haptics: any HapticsGate
    ) {
        self.session = session
        self.history = history
        self.attachmentCache = attachmentCache
        self.haptics = haptics
    }

    // MARK: - Intent

    func send(_ items: [MediaItem], to peers: [Peer]) {
        guard !items.isEmpty, !peers.isEmpty else { return }

        let logicalTotal = items.count
        var files: [MediaFileToSend] = []
        for (idx, item) in items.enumerated() {
            if let lpVideoURL = item.livePhotoVideoURL {
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

        outgoingTransfer = OutgoingMediaTransfer(totalItems: files.count, peerCount: peers.count)
        activeProgresses = []
        startProgressPolling()

        // Compute size from source URLs before they might be moved/cleaned up.
        let srcURLs = items.map(\.fileURL)
        let totalBytes = attachmentCache.fileBytes(for: srcURLs)
        let detail = items.count == 1
            ? (items[0].fileName ?? "1 photo")
            : "\(items.count) photos"
        let recordID = UUID()

        for peer in peers {
            let progresses = session.sendMedia(files, to: peer) { [weak self] result in
                switch result {
                case .success:
                    self?.outgoingTransfer?.recordCompletion()
                case .failure(let error):
                    log.error("sendMedia item failed: \(error.localizedDescription, privacy: .public)")
                    self?.haptics.heavy()
                    self?.outgoingTransfer?.recordFailure()
                }
                if self?.outgoingTransfer?.isComplete == true {
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(for: .seconds(1.5))
                        self?.outgoingTransfer = nil
                    }
                }
            }
            activeProgresses.append(contentsOf: progresses)
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let names: [String?] = items.map { item in
                guard let base = item.fileName else { return nil }
                let ext = item.fileURL.pathExtension.lowercased()
                return ext.isEmpty ? base : "\(base).\(ext)"
            }
            let cachedURLs = await attachmentCache.cache(srcURLs, names: names, forRecord: recordID)
            history.add(TransferRecord(
                id: recordID,
                peers: peers,
                direction: .sent,
                type: .photo,
                detail: detail,
                attachmentURLs: cachedURLs,
                fileBytes: totalBytes > 0 ? totalBytes : nil
            ))
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
