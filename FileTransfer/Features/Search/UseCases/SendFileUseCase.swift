import Foundation
import Observation
import OSLog

private let log = Logger(subsystem: "com.qstrnd.FileTransfer", category: "SendFile")

@Observable
@MainActor
final class SendFileUseCase {

    private(set) var outgoingTransfer: OutgoingFileTransfer?

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

    func send(_ urls: [URL], to peers: [Peer]) {
        guard !urls.isEmpty, !peers.isEmpty else { return }
        let total = urls.count
        // Clean up iOS file-picker temp-name prefix (fp_<UUID>_OriginalName.pdf → OriginalName.pdf)
        // so the original filename is preserved both in the wire format and in the cache.
        let cleanNames = urls.map { Self.cleanFileName($0) }
        let files = urls.enumerated().map { idx, url in
            FileToSend(url: url, name: cleanNames[idx], index: idx, total: total)
        }
        outgoingTransfer = OutgoingFileTransfer(totalFiles: total, peerCount: peers.count)
        activeProgresses = []
        startProgressPolling()

        let srcURLs = urls
        let totalBytes = attachmentCache.fileBytes(for: srcURLs)
        let detail = total == 1 ? cleanNames[0] : "\(total) files"
        let recordID = UUID()

        for peer in peers {
            let progresses = session.sendFiles(files, to: peer) { [weak self] result in
                switch result {
                case .success:
                    self?.outgoingTransfer?.recordCompletion()
                case .failure(let error):
                    log.error("sendFiles item failed: \(error.localizedDescription, privacy: .public)")
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
            let names: [String?] = cleanNames
            let cachedURLs = await attachmentCache.cache(srcURLs, names: names, forRecord: recordID)
            history.add(TransferRecord(
                id: recordID,
                peers: peers,
                direction: .sent,
                type: .file,
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

    /// Strips the iOS file-picker temp prefix `fp_<UUID>_` from a URL's last path component.
    /// Example: `fp_0E9F2AB0-9A09-46B2-A06F-088F6EA8660E_Report.pdf` → `Report.pdf`
    private nonisolated static func cleanFileName(_ url: URL) -> String {
        let raw = url.lastPathComponent
        // Pattern: fp_ + standard UUID (8-4-4-4-12 hex + hyphens) + _
        let uuidPattern = "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
        if let range = raw.range(of: "^fp_\(uuidPattern)_", options: .regularExpression),
           !raw[range.upperBound...].isEmpty {
            return String(raw[range.upperBound...])
        }
        return raw.isEmpty ? "file" : raw
    }

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
