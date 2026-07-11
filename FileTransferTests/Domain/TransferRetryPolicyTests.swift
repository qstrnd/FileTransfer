import CryptoKit
import Foundation
import Testing
@testable import FileTransfer

struct TransferRetryPolicyTests {

    private let policy = TransferRetryPolicy() // maxAttempts 3, base 1s, cap 8s

    @Test func transportError_retriesWithExponentialBackoff() {
        #expect(policy.decision(outcome: .transport("reset"), attempt: 1) == .retry(after: .seconds(1)))
        #expect(policy.decision(outcome: .transport("reset"), attempt: 2) == .retry(after: .seconds(2)))
    }

    @Test func transportError_fallsBackAfterMaxAttempts() {
        #expect(policy.decision(outcome: .transport("reset"), attempt: 3) == .fallbackToMPC)
    }

    @Test func serverError5xx_isRetryable() {
        #expect(policy.decision(outcome: .rejected(status: 500), attempt: 1) == .retry(after: .seconds(1)))
        #expect(policy.decision(outcome: .rejected(status: 503), attempt: 3) == .fallbackToMPC)
    }

    @Test func checksumMismatch422_isRetryable() {
        #expect(policy.decision(outcome: .rejected(status: 422), attempt: 1) == .retry(after: .seconds(1)))
    }

    @Test func other4xx_fallsBackImmediately() {
        #expect(policy.decision(outcome: .rejected(status: 400), attempt: 1) == .fallbackToMPC)
        #expect(policy.decision(outcome: .rejected(status: 404), attempt: 1) == .fallbackToMPC)
    }

    @Test func cancellation_isTerminal() {
        #expect(policy.decision(outcome: .cancelled, attempt: 1) == .fail)
    }

    @Test func backoffIsCappedAtMaxDelay() {
        let longPolicy = TransferRetryPolicy(maxAttempts: 10, baseDelay: .seconds(1), maxDelay: .seconds(8))
        #expect(longPolicy.decision(outcome: .transport("x"), attempt: 5) == .retry(after: .seconds(8)))
        #expect(longPolicy.decision(outcome: .transport("x"), attempt: 9) == .retry(after: .seconds(8)))
    }
}

struct StreamingSHA256HasherTests {

    @Test func knownVector_emptyFile() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sha_test_empty_\(UUID().uuidString)")
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let digest = try await StreamingSHA256Hasher().sha256Hex(of: url)
        #expect(digest == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    @Test func knownVector_abc() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sha_test_abc_\(UUID().uuidString)")
        try Data("abc".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let digest = try await StreamingSHA256Hasher().sha256Hex(of: url)
        #expect(digest == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func multiChunkFile_matchesSingleShotDigest() async throws {
        // 3 MiB forces multiple 1 MiB chunks through the incremental hasher.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sha_test_big_\(UUID().uuidString)")
        var bytes = Data(count: 3 * 1024 * 1024)
        for i in stride(from: 0, to: bytes.count, by: 4096) { bytes[i] = UInt8(i % 251) }
        try bytes.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let streamed = try await StreamingSHA256Hasher().sha256Hex(of: url)
        let oneShot = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        #expect(streamed == oneShot)
    }

    @Test func missingFile_throws() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sha_test_missing_\(UUID().uuidString)")
        await #expect(throws: (any Error).self) {
            _ = try await StreamingSHA256Hasher().sha256Hex(of: url)
        }
    }
}
