import Foundation
import OSLog

/// Per-batch state machine for the HTTP send path.
///
/// For each batch it computes checksums, starts uploads through the
/// `FileUploadGate`, applies `TransferRetryPolicy` to failed attempts
/// (re-resolving the peer's endpoint between attempts), falls back to MPC for
/// the batch's undelivered remainder — preserving the transferID so the
/// receiver sees one coherent incoming transfer — and, only when MPC is also
/// unavailable, reports per-item failures. `onItemCompleted` fires exactly
/// once per file no matter which transport carried it.
@MainActor
final class HTTPTransferSendCoordinator: HTTPTransferSending {
    nonisolated private static let log = Logger(subsystem: "com.qstrnd.FileTransfer", category: "HTTPTransfer")

    private let uploadGate: any FileUploadGate
    private let checksummer: any Checksumming
    private let retryPolicy: TransferRetryPolicy
    private let endpointResolver: any PeerEndpointResolving
    private weak var mpcFallback: (any MPCBatchFallback)?
    private let activityGate: (any TransferActivityGate)?

    private var localIdentity: TransferHTTPHeaders.Sender?

    init(
        uploadGate: any FileUploadGate,
        endpointResolver: any PeerEndpointResolving,
        mpcFallback: any MPCBatchFallback,
        checksummer: any Checksumming = StreamingSHA256Hasher(),
        retryPolicy: TransferRetryPolicy = TransferRetryPolicy(),
        activityGate: (any TransferActivityGate)? = nil
    ) {
        self.uploadGate = uploadGate
        self.endpointResolver = endpointResolver
        self.mpcFallback = mpcFallback
        self.checksummer = checksummer
        self.retryPolicy = retryPolicy
        self.activityGate = activityGate
        uploadGate.events = self
    }

    // MARK: - Batch state

    private enum ItemState {
        case preparing            // checksum in progress
        case uploading(attempt: Int)
        case waitingRetry
        case delivered
        case failed
        case handedToMPC
    }

    private final class Item {
        enum Source {
            case media(MediaFileToSend)
            case file(FileToSend)
        }

        let source: Source
        let itemKey: String
        let info: IncomingTransferItemInfo
        let progress: Progress
        let expectedBytes: Int64
        var state: ItemState = .preparing
        var sha256Hex: String?
        var retryTask: Task<Void, Never>?

        init(source: Source, itemKey: String, info: IncomingTransferItemInfo, expectedBytes: Int64) {
            self.source = source
            self.itemKey = itemKey
            self.info = info
            self.expectedBytes = expectedBytes
            self.progress = Progress(totalUnitCount: max(1, expectedBytes))
        }

        var fileURL: URL {
            switch source {
            case .media(let file): file.url
            case .file(let file):  file.url
            }
        }
    }

    private final class Batch {
        let transferID: String
        let peer: Peer
        var endpoint: PeerEndpoint
        var items: [String: Item] = [:]
        let onItemCompleted: @MainActor (Result<Void, TransferSendError>) -> Void
        var fellBackToMPC = false
        var mpcMirrorTask: Task<Void, Never>?

        init(transferID: String, peer: Peer, endpoint: PeerEndpoint,
             onItemCompleted: @escaping @MainActor (Result<Void, TransferSendError>) -> Void) {
            self.transferID = transferID
            self.peer = peer
            self.endpoint = endpoint
            self.onItemCompleted = onItemCompleted
        }
    }

    private var batches: [String: Batch] = [:]          // by transferID
    private var batchByItemKey: [String: String] = [:]  // itemKey → transferID

    // MARK: - HTTPTransferSending

    func setLocalIdentity(deviceID: UUID, displayName: String) {
        localIdentity = TransferHTTPHeaders.Sender(deviceID: deviceID, displayName: displayName)
    }

    var isIdle: Bool { batches.isEmpty }
    var onIdle: (@MainActor () -> Void)?

    func sendMedia(
        _ files: [MediaFileToSend], to peer: Peer, endpoint: PeerEndpoint,
        onItemCompleted: @escaping @MainActor (Result<Void, TransferSendError>) -> Void
    ) -> [Progress] {
        let transferID = Self.newTransferID()
        let items = files.map { file in
            let ext = file.url.pathExtension.isEmpty
                ? (file.kind == .livePhotoVideo ? "mov" : "jpg")
                : file.url.pathExtension.lowercased()
            let info = IncomingTransferItemInfo(
                transferID: transferID, index: file.logicalIndex, total: file.logicalTotal,
                payload: .media, kind: file.kind,
                fileName: file.suggestedName, fileExtension: ext
            )
            return Item(
                source: .media(file),
                itemKey: Self.itemKey(transferID: transferID, index: file.logicalIndex, kind: file.kind),
                info: info,
                expectedBytes: Self.fileSize(file.url)
            )
        }
        return startBatch(transferID: transferID, items: items, peer: peer,
                          endpoint: endpoint, onItemCompleted: onItemCompleted)
    }

    func sendFiles(
        _ files: [FileToSend], to peer: Peer, endpoint: PeerEndpoint,
        onItemCompleted: @escaping @MainActor (Result<Void, TransferSendError>) -> Void
    ) -> [Progress] {
        let transferID = Self.newTransferID()
        let items = files.map { file in
            let ext = file.url.pathExtension.isEmpty ? "bin" : file.url.pathExtension.lowercased()
            let info = IncomingTransferItemInfo(
                transferID: transferID, index: file.index, total: file.total,
                payload: .file, kind: .regular,
                fileName: file.name, fileExtension: ext
            )
            return Item(
                source: .file(file),
                itemKey: Self.itemKey(transferID: transferID, index: file.index, kind: .regular),
                info: info,
                expectedBytes: Self.fileSize(file.url)
            )
        }
        return startBatch(transferID: transferID, items: items, peer: peer,
                          endpoint: endpoint, onItemCompleted: onItemCompleted)
    }

    // MARK: - Batch lifecycle

    private func startBatch(
        transferID: String, items: [Item], peer: Peer, endpoint: PeerEndpoint,
        onItemCompleted: @escaping @MainActor (Result<Void, TransferSendError>) -> Void
    ) -> [Progress] {
        let batch = Batch(transferID: transferID, peer: peer, endpoint: endpoint,
                          onItemCompleted: onItemCompleted)
        for item in items {
            batch.items[item.itemKey] = item
            batchByItemKey[item.itemKey] = transferID
        }
        batches[transferID] = batch
        Self.log.info("batch \(transferID, privacy: .public) → \(peer.displayName, privacy: .public): \(items.count) item(s) via HTTP")
        activityGate?.startActivity(
            key: transferID, peerName: peer.displayName,
            direction: .send, totalItems: items.count
        )

        for item in items {
            Task { [weak self] in
                await self?.prepareAndUpload(itemKey: item.itemKey)
            }
        }
        return items.map(\.progress)
    }

    /// Aggregated batch progress for the Live Activity: byte fraction across
    /// all items + count of terminally-delivered items.
    private func notifyActivityProgress(_ batch: Batch) {
        guard activityGate != nil else { return }
        let items = batch.items.values
        let totalBytes = items.reduce(Int64(0)) { $0 + $1.progress.totalUnitCount }
        let sentBytes = items.reduce(Int64(0)) { $0 + $1.progress.completedUnitCount }
        let delivered = items.count { if case .delivered = $0.state { true } else { false } }
        let progress = totalBytes > 0 ? Double(sentBytes) / Double(totalBytes) : 0
        activityGate?.updateActivity(key: batch.transferID, progress: progress, completedItems: delivered)
    }

    private func prepareAndUpload(itemKey: String) async {
        guard let (batch, item) = lookup(itemKey), case .preparing = item.state else { return }
        do {
            // Checksum once per item; retries reuse it (the file is immutable
            // for the transfer's duration — it's a picker/export temp copy).
            if item.sha256Hex == nil {
                item.sha256Hex = try await checksummer.sha256Hex(of: item.fileURL)
            }
        } catch {
            Self.log.error("checksum failed for \(itemKey, privacy: .public): \(error.localizedDescription, privacy: .public)")
            complete(item, in: batch, with: .failure(.sourceFileMissing))
            return
        }
        startAttempt(itemKey: itemKey, attempt: 1)
    }

    private func startAttempt(itemKey: String, attempt: Int) {
        guard let (batch, item) = lookup(itemKey), !batch.fellBackToMPC,
              let sha256Hex = item.sha256Hex else { return }
        guard let localIdentity else {
            Self.log.error("no local identity — cannot build upload headers")
            complete(item, in: batch, with: .failure(.peerUnreachable))
            return
        }
        item.state = .uploading(attempt: attempt)
        // Retries restart the byte count; summed batch progress dips honestly
        // instead of double-counting resent bytes.
        item.progress.completedUnitCount = 0

        let headers = TransferHTTPHeaders.encode(item: item.info, sender: localIdentity, sha256Hex: sha256Hex)
        uploadGate.upload(FileUploadRequest(
            endpoint: batch.endpoint,
            fileURL: item.fileURL,
            headers: headers,
            itemKey: itemKey,
            expectedBytes: item.expectedBytes
        ))
    }

    // MARK: - Retry / fallback / completion

    private func handleFailedAttempt(_ item: Item, in batch: Batch, outcome: FileUploadOutcome, attempt: Int) {
        switch retryPolicy.decision(outcome: outcome, attempt: attempt) {
        case .retry(let delay):
            Self.log.info("retrying \(item.itemKey, privacy: .public) (attempt \(attempt + 1)) in \(delay.components.seconds)s")
            item.state = .waitingRetry
            item.retryTask = Task { [weak self] in
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                await self?.refreshEndpointAndRetry(itemKey: item.itemKey, attempt: attempt + 1)
            }
        case .fallbackToMPC:
            fallBackToMPC(batch, trigger: outcome)
        case .fail:
            complete(item, in: batch, with: .failure(Self.sendError(from: outcome)))
        }
    }

    private func refreshEndpointAndRetry(itemKey: String, attempt: Int) async {
        guard let (batch, item) = lookup(itemKey), !batch.fellBackToMPC,
              case .waitingRetry = item.state else { return }
        // The endpoint may have gone stale (listener restarted on a new port);
        // re-resolve before retrying so IP/port changes heal mid-batch.
        if let deviceID = batch.peer.deviceID {
            endpointResolver.invalidate(deviceID: deviceID)
            if let fresh = await endpointResolver.resolveEndpoint(for: deviceID) {
                batch.endpoint = fresh
            }
        }
        guard let (batchAfter, itemAfter) = lookup(itemKey), !batchAfter.fellBackToMPC,
              case .waitingRetry = itemAfter.state else { return }
        startAttempt(itemKey: itemKey, attempt: attempt)
    }

    private func fallBackToMPC(_ batch: Batch, trigger: FileUploadOutcome) {
        guard !batch.fellBackToMPC else { return }
        batch.fellBackToMPC = true

        // Stop everything still in flight or scheduled for this batch.
        for item in batch.items.values {
            item.retryTask?.cancel()
            item.retryTask = nil
        }
        uploadGate.cancelUploads(withPrefix: batch.transferID)

        let undelivered = batch.items.values.filter { item in
            switch item.state {
            case .delivered, .failed: false
            default: true
            }
        }
        guard !undelivered.isEmpty else { return }
        for item in undelivered { item.state = .handedToMPC }

        Self.log.warning("batch \(batch.transferID, privacy: .public): HTTP exhausted (\(String(describing: trigger), privacy: .public)) — falling back to MPC for \(undelivered.count) item(s)")

        let mediaFiles = undelivered.compactMap { if case .media(let f) = $0.source { f } else { nil } }
        let regularFiles = undelivered.compactMap { if case .file(let f) = $0.source { f } else { nil } }

        // Bridge each MPC per-item terminal outcome straight through to the
        // batch's completion closure — identity doesn't matter to the UI,
        // only that the total count of terminal outcomes is exact.
        var mpcProgresses: [Progress] = []
        let onMPCItemCompleted: @MainActor (Result<Void, TransferSendError>) -> Void = { [weak self] result in
            guard let self, let batch = batches[batch.transferID] else { return }
            settleOneMPCItem(in: batch, result: result)
        }

        if let mpcFallback {
            if !mediaFiles.isEmpty {
                mpcProgresses += mpcFallback.sendMedia(mediaFiles, to: batch.peer,
                                                       transferID: batch.transferID,
                                                       onItemCompleted: onMPCItemCompleted)
            }
            if !regularFiles.isEmpty {
                mpcProgresses += mpcFallback.sendFiles(regularFiles, to: batch.peer,
                                                       transferID: batch.transferID,
                                                       onItemCompleted: onMPCItemCompleted)
            }
        }

        guard !mpcProgresses.isEmpty else {
            // MPC is also unavailable (no session / peer gone) — the honest end.
            Self.log.error("batch \(batch.transferID, privacy: .public): MPC fallback unavailable — failing \(undelivered.count) item(s)")
            for item in undelivered {
                complete(item, in: batch, with: .failure(.peerUnreachable))
            }
            return
        }

        mirrorMPCProgress(mpcProgresses, onto: undelivered.map(\.progress), in: batch)
    }

    /// Marks one still-handed-to-MPC item terminal and forwards the outcome.
    private func settleOneMPCItem(in batch: Batch, result: Result<Void, TransferSendError>) {
        guard let item = batch.items.values.first(where: {
            if case .handedToMPC = $0.state { true } else { false }
        }) else { return }
        if case .success = result {
            item.progress.completedUnitCount = item.progress.totalUnitCount
        }
        complete(item, in: batch, with: result)
    }

    /// Mirrors MPC transfer progress onto the original per-item Progress
    /// objects (the ones the send UI is polling) for the fallback's duration.
    private func mirrorMPCProgress(_ sources: [Progress], onto targets: [Progress], in batch: Batch) {
        batch.mpcMirrorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, let batch = batches[batch.transferID] else { return }
                let stillRunning = batch.items.values.contains {
                    if case .handedToMPC = $0.state { true } else { false }
                }
                guard stillRunning else { return }
                for (source, target) in zip(sources, targets)
                where target.completedUnitCount < target.totalUnitCount {
                    target.completedUnitCount =
                        Int64(source.fractionCompleted * Double(target.totalUnitCount))
                }
                notifyActivityProgress(batch)
            }
        }
    }

    private func complete(_ item: Item, in batch: Batch, with result: Result<Void, TransferSendError>) {
        switch item.state {
        case .delivered, .failed: return // already terminal
        default: break
        }
        item.state = if case .success = result { .delivered } else { .failed }
        batchByItemKey[item.itemKey] = nil
        batch.onItemCompleted(result)

        let allDone = batch.items.values.allSatisfy {
            switch $0.state {
            case .delivered, .failed: true
            default: false
            }
        }
        if allDone {
            Self.log.info("batch \(batch.transferID, privacy: .public) finished")
            batch.mpcMirrorTask?.cancel()
            batches[batch.transferID] = nil
            let anyFailed = batch.items.values.contains {
                if case .failed = $0.state { true } else { false }
            }
            activityGate?.endActivity(key: batch.transferID, outcome: anyFailed ? .failure : .success)
            if batches.isEmpty { onIdle?() }
        } else {
            notifyActivityProgress(batch)
        }
    }

    // MARK: - Helpers

    private func lookup(_ itemKey: String) -> (Batch, Item)? {
        guard let transferID = batchByItemKey[itemKey],
              let batch = batches[transferID],
              let item = batch.items[itemKey] else { return nil }
        return (batch, item)
    }

    nonisolated private static func sendError(from outcome: FileUploadOutcome) -> TransferSendError {
        switch outcome {
        case .delivered:               .peerUnreachable // unreachable in practice
        case .cancelled:               .cancelled
        case .rejected(let status):    .serverRejected(status: status)
        case .transport(let message):  .connectionFailed(message)
        }
    }

    nonisolated private static func newTransferID() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    nonisolated private static func itemKey(transferID: String, index: Int, kind: MediaFileKind) -> String {
        "\(transferID)/\(index)/\(kind.rawValue)"
    }

    nonisolated private static func fileSize(_ url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64).flatMap { $0 } ?? 0
    }
}

// MARK: - FileUploadEvents

extension HTTPTransferSendCoordinator: FileUploadEvents {

    func uploadProgressed(itemKey: String, sentBytes: Int64, totalBytes: Int64) {
        guard let (batch, item) = lookup(itemKey), !batch.fellBackToMPC,
              case .uploading = item.state else { return }
        if totalBytes > 0 { item.progress.totalUnitCount = totalBytes }
        item.progress.completedUnitCount = sentBytes
        notifyActivityProgress(batch)
    }

    func uploadFinished(itemKey: String, outcome: FileUploadOutcome) {
        guard let (batch, item) = lookup(itemKey) else { return }
        // Outcomes for items already handed to MPC (their HTTP task was
        // cancelled) or otherwise settled must not re-enter the state machine.
        guard case .uploading(let attempt) = item.state else { return }

        switch outcome {
        case .delivered:
            item.progress.completedUnitCount = item.progress.totalUnitCount
            complete(item, in: batch, with: .success(()))
        case .cancelled where batch.fellBackToMPC:
            break // expected: we cancelled it ourselves during fallback
        default:
            handleFailedAttempt(item, in: batch, outcome: outcome, attempt: attempt)
        }
    }
}
