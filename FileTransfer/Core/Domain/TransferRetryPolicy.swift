import Foundation

/// What the send coordinator should do after a failed upload attempt.
nonisolated enum RetryDecision: Sendable, Equatable {
    case retry(after: Duration)
    case fallbackToMPC
    case fail
}

/// Pure decision table for upload retries.
///
/// Retryable outcomes — transport errors, 5xx, and 422 (bytes corrupted in
/// transit; a re-read + re-send usually heals) — get exponential backoff up
/// to `maxAttempts`, then fall back to MPC. Other 4xx statuses mean the two
/// ends disagree about the protocol; retrying the same bytes can't help, so
/// fall back immediately. Cancellation is terminal.
nonisolated struct TransferRetryPolicy: Sendable {
    var maxAttempts = 3
    var baseDelay: Duration = .seconds(1)
    var maxDelay: Duration = .seconds(8)

    /// - Parameter attempt: 1-based number of the attempt that just failed.
    func decision(outcome: FileUploadOutcome, attempt: Int) -> RetryDecision {
        switch outcome {
        case .delivered:
            return .fail // Not a failure; callers never ask. Defensive default.
        case .cancelled:
            return .fail
        case .rejected(let status) where status == 422 || (500...599).contains(status):
            return retryOrFallback(attempt: attempt)
        case .rejected:
            return .fallbackToMPC
        case .transport:
            return retryOrFallback(attempt: attempt)
        }
    }

    private func retryOrFallback(attempt: Int) -> RetryDecision {
        guard attempt < maxAttempts else { return .fallbackToMPC }
        let exponent = max(0, attempt - 1)
        let delay = baseDelay * (1 << exponent)
        return .retry(after: min(delay, maxDelay))
    }
}
