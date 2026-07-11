import Foundation
import OSLog

/// Uploads files to peers' transfer servers using a background
/// `URLSessionConfiguration` from day one: file-based upload tasks survive
/// app suspension (Phase 2), and while the app is active the delegate
/// callbacks fire normally, so foreground behavior matches a regular session.
///
/// Progress and completion flow through `FileUploadEvents` keyed by the
/// request's `itemKey`, which is also stored as `taskDescription` so
/// completions can be matched even after a relaunch reattaches the session.
@MainActor
final class BackgroundURLSessionUploadClient: NSObject, FileUploadGate {
    nonisolated private static let log = Logger(subsystem: "com.qstrnd.FileTransfer", category: "UploadClient")
    nonisolated static let sessionIdentifier = "com.qstrnd.FileTransfer.upload"

    /// One background session identifier ⇒ one client. The facade composes
    /// against this instance, and `awakeForBackgroundEvents` can reattach the
    /// session on a cold background launch without the facade existing yet.
    static let shared = BackgroundURLSessionUploadClient()

    /// Forces session (re)creation so a cold-launched app reattaches the
    /// delegate and receives the queued task completions.
    static func awakeForBackgroundEvents() {
        _ = shared.session
    }

    weak var events: (any FileUploadEvents)?

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.allowsCellularAccess = false
        // LAN peers should fail fast so the retry policy governs recovery,
        // not the session's own connectivity waiting.
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 600
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    /// Attempt-level Progress objects by task identifier (main-actor only).
    private var progressByTask: [Int: Progress] = [:]
    private var itemKeyByTask: [Int: String] = [:]

    // MARK: - FileUploadGate

    @discardableResult
    func upload(_ request: FileUploadRequest) -> Progress {
        let progress = Progress(totalUnitCount: max(1, request.expectedBytes))

        guard let baseURL = request.endpoint.baseURL,
              let url = URL(string: "/v1/transfer", relativeTo: baseURL) else {
            Self.log.error("invalid endpoint for \(request.itemKey, privacy: .public)")
            notifyFinished(itemKey: request.itemKey, outcome: .transport("invalid endpoint URL"))
            return progress
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        let task = session.uploadTask(with: urlRequest, fromFile: request.fileURL)
        task.taskDescription = request.itemKey
        progressByTask[task.taskIdentifier] = progress
        itemKeyByTask[task.taskIdentifier] = request.itemKey
        Self.log.info("upload start \(request.itemKey, privacy: .public) → \(request.endpoint.host, privacy: .public):\(request.endpoint.port) (\(request.expectedBytes) bytes)")
        task.resume()
        return progress
    }

    func cancelUploads(withPrefix transferID: String) {
        session.getAllTasks { tasks in
            for task in tasks where task.taskDescription?.hasPrefix(transferID) == true {
                task.cancel()
            }
        }
    }

    // MARK: - Event fan-out

    private func notifyFinished(itemKey: String, outcome: FileUploadOutcome) {
        events?.uploadFinished(itemKey: itemKey, outcome: outcome)
    }
}

// MARK: - URLSessionTaskDelegate (nonisolated; hops to main)

extension BackgroundURLSessionUploadClient: URLSessionTaskDelegate {

    nonisolated func urlSession(
        _ session: URLSession, task: URLSessionTask,
        didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64
    ) {
        let taskID = task.taskIdentifier
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let progress = progressByTask[taskID] {
                if totalBytesExpectedToSend > 0 { progress.totalUnitCount = totalBytesExpectedToSend }
                progress.completedUnitCount = totalBytesSent
            }
            if let itemKey = itemKeyByTask[taskID] {
                events?.uploadProgressed(itemKey: itemKey, sentBytes: totalBytesSent, totalBytes: totalBytesExpectedToSend)
            }
        }
    }

    /// Fired after a relaunched-for-background-events session has delivered
    /// all queued callbacks; hands control back to iOS via the stored handler.
    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        let identifier = session.configuration.identifier
        Task { @MainActor in
            Self.log.info("background session events drained")
            BackgroundSessionCompletionStore.shared.complete(session: identifier ?? Self.sessionIdentifier)
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let taskID = task.taskIdentifier
        let itemKeyFromTask = task.taskDescription
        let status = (task.response as? HTTPURLResponse)?.statusCode

        let outcome: FileUploadOutcome
        if let error = error as NSError? {
            outcome = error.code == NSURLErrorCancelled
                ? .cancelled
                : .transport(error.localizedDescription)
        } else if let status {
            switch status {
            case 200, 409: outcome = .delivered   // 409 = already stored (retry after lost response)
            default:       outcome = .rejected(status: status)
            }
        } else {
            outcome = .transport("no response")
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            // Mark the attempt's Progress complete on success so summed
            // byte-based UI progress can't stall at 99% on tiny files whose
            // didSendBodyData never fired.
            if outcome == .delivered, let progress = progressByTask[taskID] {
                progress.completedUnitCount = progress.totalUnitCount
            }
            progressByTask[taskID] = nil
            let itemKey = itemKeyByTask.removeValue(forKey: taskID) ?? itemKeyFromTask
            guard let itemKey else {
                Self.log.warning("completion for unknown task \(taskID) — likely relaunch reattachment")
                return
            }
            Self.log.info("upload finished \(itemKey, privacy: .public): \(String(describing: outcome), privacy: .public)")
            notifyFinished(itemKey: itemKey, outcome: outcome)
        }
    }
}
