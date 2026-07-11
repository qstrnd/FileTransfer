import CryptoKit
import Foundation
import Network
import OSLog

/// Tracks which transfer items have been fully received so duplicate uploads
/// (retries after a lost 200) can be answered 409 without re-reading the body.
/// Thread-safe: consulted directly from connection queues and the main actor.
nonisolated final class TransferReceptionLedger: @unchecked Sendable {
    private let lock = NSLock()
    private var completedKeys: Set<String> = []
    private var startedTransferIDs: Set<String> = []

    func isCompleted(itemKey: String) -> Bool {
        lock.withLock { completedKeys.contains(itemKey) }
    }

    func markCompleted(itemKey: String) {
        lock.withLock { _ = completedKeys.insert(itemKey) }
    }

    /// Returns true the first time a transferID is seen (drives "did start receiving").
    func markStarted(transferID: String) -> Bool {
        lock.withLock { startedTransferIDs.insert(transferID).inserted }
    }

    func reset() {
        lock.withLock {
            completedKeys.removeAll()
            startedTransferIDs.removeAll()
        }
    }
}

/// Handles a single inbound upload connection: parses the HTTP head, streams
/// the body straight to a temp file (never buffered in memory) while feeding
/// an incremental SHA-256, verifies the digest, and writes the response.
///
/// One instance per NWConnection. All mutable state is confined to the
/// connection's serial queue; the completion callback is invoked exactly once.
nonisolated final class HTTPConnectionHandler: @unchecked Sendable {
    nonisolated private static let log = Logger(subsystem: "com.qstrnd.FileTransfer", category: "HTTPServer")

    enum Outcome: Sendable {
        /// Item verified and stored; deliver to the app.
        case delivered(IncomingTransferItemInfo, TransferHTTPHeaders.Sender, URL, firstOfTransfer: Bool)
        /// Head parsed but item already fully received (sender retry) — answered 409.
        case duplicate(IncomingTransferItemInfo)
        /// Anything that ended without a stored item (malformed, checksum, I/O, timeout, cancel).
        case failed(String)
    }

    private static let maxHeadBytes = 16 * 1024
    private static let chunkSize = 256 * 1024
    private static let idleTimeout: TimeInterval = 30

    private let connection: NWConnection
    private let queue: DispatchQueue
    private let ledger: TransferReceptionLedger
    private let onFinish: @Sendable (HTTPConnectionHandler, Outcome) -> Void
    /// Fired once, right after the head parses and the item is accepted, so
    /// the server can bump its in-flight count before body bytes stream in.
    private let onBodyStart: @Sendable (HTTPConnectionHandler) -> Void

    // Confined to `queue` (all connection callbacks and timers run there).
    private var headBuffer = Data()
    private var item: IncomingTransferItemInfo?
    private var sender: TransferHTTPHeaders.Sender?
    private var expectedDigest = ""
    private var expectedBytes: Int64 = 0
    private var receivedBytes: Int64 = 0
    private var hasher = SHA256()
    private var fileHandle: FileHandle?
    private var destinationURL: URL?
    private var finished = false
    private var idleTimer: DispatchSourceTimer?
    private var bodyStarted = false

    init(
        connection: NWConnection,
        queue: DispatchQueue,
        ledger: TransferReceptionLedger,
        onBodyStart: @escaping @Sendable (HTTPConnectionHandler) -> Void,
        onFinish: @escaping @Sendable (HTTPConnectionHandler, Outcome) -> Void
    ) {
        self.connection = connection
        self.queue = queue
        self.ledger = ledger
        self.onBodyStart = onBodyStart
        self.onFinish = onFinish
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .failed(let error):
                finish(.failed("connection failed: \(error)"), response: nil)
            case .cancelled:
                if !finished {
                    finished = true
                    cleanupPartialFile()
                    onFinish(self, .failed("connection cancelled"))
                }
            default:
                break
            }
        }
        resetIdleTimer()
        connection.start(queue: queue)
        receiveHead()
    }

    func cancel() {
        queue.async { [self] in
            finish(.failed("server stopping"), response: nil)
        }
    }

    // MARK: - Head

    private func receiveHead() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.chunkSize) { [weak self] data, _, isComplete, error in
            guard let self, !finished else { return }
            resetIdleTimer()
            if let error {
                finish(.failed("receive error in head: \(error)"), response: nil)
                return
            }
            if let data { headBuffer.append(data) }

            if let terminator = HTTPRequestHead.headTerminatorRange(in: headBuffer) {
                let headData = headBuffer.subdata(in: headBuffer.startIndex..<terminator.lowerBound)
                let bodyPrefix = headBuffer.subdata(in: terminator.upperBound..<headBuffer.endIndex)
                headBuffer = Data()
                processHead(headData, bodyPrefix: bodyPrefix)
            } else if headBuffer.count > Self.maxHeadBytes {
                finish(.failed("head too large"), response: .badRequest)
            } else if isComplete {
                finish(.failed("connection closed before head completed"), response: nil)
            } else {
                receiveHead()
            }
        }
    }

    private func processHead(_ headData: Data, bodyPrefix: Data) {
        guard let head = HTTPRequestHead(parsing: headData) else {
            finish(.failed("malformed request head"), response: .badRequest)
            return
        }
        guard head.method == "PUT", head.path == "/v1/transfer" else {
            finish(.failed("unsupported \(head.method) \(head.path)"), response: .notFound)
            return
        }
        guard let decoded = TransferHTTPHeaders.decode(head.headers) else {
            finish(.failed("missing/invalid X-FT headers"), response: .badRequest)
            return
        }
        guard let length = head.contentLength else {
            finish(.failed("missing Content-Length"), response: .lengthRequired)
            return
        }

        let itemKey = "\(decoded.item.transferID)/\(decoded.item.index)/\(decoded.item.kind.rawValue)"
        if ledger.isCompleted(itemKey: itemKey) {
            Self.log.info("duplicate item \(itemKey, privacy: .public) — responding 409")
            finish(.duplicate(decoded.item), response: .conflict)
            return
        }

        item = decoded.item
        sender = decoded.sender
        expectedDigest = decoded.sha256Hex
        expectedBytes = length
        receivedBytes = 0
        hasher = SHA256()

        // Same naming convention as the MPC receive path (incl. the _lpv tag).
        let kindTag = decoded.item.kind == .livePhotoVideo ? "_lpv" : ""
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(
            "http_recv_\(decoded.item.transferID)_\(decoded.item.index)\(kindTag)_\(UUID().uuidString.prefix(8)).\(decoded.item.fileExtension)"
        )
        FileManager.default.createFile(atPath: dest.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: dest) else {
            finish(.failed("cannot open destination file"), response: .serverError)
            return
        }
        destinationURL = dest
        fileHandle = handle
        bodyStarted = true
        onBodyStart(self)

        Self.log.info("receiving \(itemKey, privacy: .public) \(length) bytes")
        if !bodyPrefix.isEmpty {
            consumeBody(bodyPrefix, isComplete: false)
        } else if expectedBytes == 0 {
            finalizeBody()
        } else {
            receiveBody()
        }
    }

    // MARK: - Body

    private func receiveBody() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.chunkSize) { [weak self] data, _, isComplete, error in
            guard let self, !finished else { return }
            resetIdleTimer()
            if let error {
                finish(.failed("receive error in body: \(error)"), response: nil)
                return
            }
            consumeBody(data ?? Data(), isComplete: isComplete)
        }
    }

    private func consumeBody(_ data: Data, isComplete: Bool) {
        if !data.isEmpty {
            // Ignore any bytes past the declared length (pipelining is unsupported).
            let remaining = expectedBytes - receivedBytes
            let usable = data.count <= remaining ? data : data.prefix(Int(remaining))
            do {
                try fileHandle?.write(contentsOf: usable)
            } catch {
                finish(.failed("file write failed: \(error)"), response: .serverError)
                return
            }
            hasher.update(data: usable)
            receivedBytes += Int64(usable.count)
        }

        if receivedBytes >= expectedBytes {
            finalizeBody()
        } else if isComplete {
            finish(.failed("connection closed mid-body (\(receivedBytes)/\(expectedBytes))"), response: nil)
        } else {
            receiveBody()
        }
    }

    private func finalizeBody() {
        try? fileHandle?.close()
        fileHandle = nil

        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard digest == expectedDigest else {
            Self.log.error("checksum mismatch: got \(digest, privacy: .public) expected \(self.expectedDigest, privacy: .public)")
            finish(.failed("checksum mismatch"), response: .unprocessable)
            return
        }

        guard let item, let sender, let destinationURL else {
            finish(.failed("internal state missing at finalize"), response: .serverError)
            return
        }
        let itemKey = "\(item.transferID)/\(item.index)/\(item.kind.rawValue)"
        ledger.markCompleted(itemKey: itemKey)
        // LP companion videos never announce a transfer start (matching the MPC
        // path) — so they must not consume the transfer's one "first item" flag,
        // or a video finishing first would swallow the announcement entirely.
        let isFirst = item.kind != .livePhotoVideo && ledger.markStarted(transferID: item.transferID)
        Self.log.info("delivered \(itemKey, privacy: .public)")
        finish(.delivered(item, sender, destinationURL, firstOfTransfer: isFirst), response: .ok)
    }

    // MARK: - Finish / response

    private struct HTTPResponse {
        let status: Int
        let reason: String

        static let ok             = HTTPResponse(status: 200, reason: "OK")
        static let badRequest     = HTTPResponse(status: 400, reason: "Bad Request")
        static let notFound       = HTTPResponse(status: 404, reason: "Not Found")
        static let conflict       = HTTPResponse(status: 409, reason: "Conflict")
        static let lengthRequired = HTTPResponse(status: 411, reason: "Length Required")
        static let unprocessable  = HTTPResponse(status: 422, reason: "Unprocessable Content")
        static let serverError    = HTTPResponse(status: 500, reason: "Internal Server Error")

        var data: Data {
            Data("HTTP/1.1 \(status) \(reason)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8)
        }
    }

    private func finish(_ outcome: Outcome, response: HTTPResponse?) {
        guard !finished else { return }
        finished = true
        idleTimer?.cancel()
        idleTimer = nil
        try? fileHandle?.close()
        fileHandle = nil
        if case .delivered = outcome {} else { cleanupPartialFile() }

        if let response {
            connection.send(content: response.data, completion: .contentProcessed { [connection] _ in
                connection.cancel()
            })
        } else {
            connection.cancel()
        }
        onFinish(self, outcome)
    }

    private func cleanupPartialFile() {
        if let destinationURL {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        destinationURL = nil
    }

    private func resetIdleTimer() {
        idleTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + Self.idleTimeout)
        timer.setEventHandler { [weak self] in
            self?.finish(.failed("idle timeout"), response: nil)
        }
        timer.resume()
        idleTimer = timer
    }
}
