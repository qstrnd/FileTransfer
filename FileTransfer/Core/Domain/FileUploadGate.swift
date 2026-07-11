import Foundation

/// One file upload to a peer's transfer server.
nonisolated struct FileUploadRequest: Sendable {
    let endpoint: PeerEndpoint
    let fileURL: URL
    /// Complete X-FT-* set built by `TransferHTTPHeaders.encode`.
    let headers: [String: String]
    /// `"<transferID>/<index>/<kind>"` — stable across retries; also used as
    /// the URLSession task description so completions can be matched after
    /// an app relaunch.
    let itemKey: String
    let expectedBytes: Int64
}

/// Terminal outcome of a single upload attempt (not of the item — the send
/// coordinator decides whether to retry, fall back, or fail).
nonisolated enum FileUploadOutcome: Sendable, Equatable {
    /// 200 (stored) or 409 (already stored — a retry after a lost response).
    case delivered
    /// Any other HTTP status.
    case rejected(status: Int)
    /// Connection-level failure: refused, reset, timeout, unreachable.
    case transport(String)
    case cancelled
}

@MainActor
protocol FileUploadGate: AnyObject {
    var events: (any FileUploadEvents)? { get set }
    /// Starts the upload and returns a Progress tracking bytes sent for this
    /// attempt. The coordinator owns per-item Progress; this one is per-attempt.
    @discardableResult
    func upload(_ request: FileUploadRequest) -> Progress
    /// Cancels all in-flight uploads whose itemKey starts with `transferID`.
    func cancelUploads(withPrefix transferID: String)
}

@MainActor
protocol FileUploadEvents: AnyObject {
    func uploadProgressed(itemKey: String, sentBytes: Int64, totalBytes: Int64)
    func uploadFinished(itemKey: String, outcome: FileUploadOutcome)
}
