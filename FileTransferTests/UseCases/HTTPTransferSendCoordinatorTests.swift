import Foundation
import Testing
@testable import FileTransfer

// MARK: - Fakes

@MainActor
private final class FakeUploadGate: FileUploadGate {
    weak var events: (any FileUploadEvents)?
    private(set) var requests: [FileUploadRequest] = []
    private(set) var cancelledPrefixes: [String] = []

    func upload(_ request: FileUploadRequest) -> Progress {
        requests.append(request)
        return Progress(totalUnitCount: request.expectedBytes)
    }

    func cancelUploads(withPrefix transferID: String) {
        cancelledPrefixes.append(transferID)
    }

    func finish(_ itemKey: String, with outcome: FileUploadOutcome) {
        events?.uploadFinished(itemKey: itemKey, outcome: outcome)
    }
}

@MainActor
private final class FakeEndpointResolver: PeerEndpointResolving {
    var endpoint: PeerEndpoint? = PeerEndpoint(host: "10.0.0.9", port: 1234)
    private(set) var invalidated: [UUID] = []

    func start() {}
    func stop() {}
    func cachedEndpoint(for deviceID: UUID) -> PeerEndpoint? { endpoint }
    func resolveEndpoint(for deviceID: UUID) async -> PeerEndpoint? { endpoint }
    func invalidate(deviceID: UUID) { invalidated.append(deviceID) }
}

@MainActor
private final class FakeMPCFallback: MPCBatchFallback {
    /// When false, sends return [] — simulating "no MPC session / peer gone".
    var available = true
    private(set) var mediaCalls: [(files: [MediaFileToSend], transferID: String)] = []
    private(set) var fileCalls: [(files: [FileToSend], transferID: String)] = []
    private var pendingCompletions: [@MainActor (Result<Void, TransferSendError>) -> Void] = []

    func sendMedia(_ files: [MediaFileToSend], to peer: Peer, transferID: String, onItemCompleted: @escaping @MainActor (Result<Void, TransferSendError>) -> Void) -> [Progress] {
        guard available else { return [] }
        mediaCalls.append((files, transferID))
        pendingCompletions.append(contentsOf: Array(repeating: onItemCompleted, count: files.count))
        return files.map { _ in Progress(totalUnitCount: 100) }
    }

    func sendFiles(_ files: [FileToSend], to peer: Peer, transferID: String, onItemCompleted: @escaping @MainActor (Result<Void, TransferSendError>) -> Void) -> [Progress] {
        guard available else { return [] }
        fileCalls.append((files, transferID))
        pendingCompletions.append(contentsOf: Array(repeating: onItemCompleted, count: files.count))
        return files.map { _ in Progress(totalUnitCount: 100) }
    }

    func completeAll(with result: Result<Void, TransferSendError>) {
        let completions = pendingCompletions
        pendingCompletions = []
        for completion in completions { completion(result) }
    }
}

private struct InstantChecksummer: Checksumming {
    func sha256Hex(of fileURL: URL) async throws -> String {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return String(repeating: "0", count: 64)
    }
}

// MARK: - Helpers

@MainActor
private struct Harness {
    let coordinator: HTTPTransferSendCoordinator
    let uploadGate: FakeUploadGate
    let resolver: FakeEndpointResolver
    let mpc: FakeMPCFallback
    let endpoint = PeerEndpoint(host: "10.0.0.9", port: 1234)
    let peer = Peer(displayName: "🦊 Bob", deviceID: UUID())

    init(retryPolicy: TransferRetryPolicy = TransferRetryPolicy(maxAttempts: 2, baseDelay: .milliseconds(1), maxDelay: .milliseconds(4))) {
        uploadGate = FakeUploadGate()
        resolver = FakeEndpointResolver()
        mpc = FakeMPCFallback()
        coordinator = HTTPTransferSendCoordinator(
            uploadGate: uploadGate,
            endpointResolver: resolver,
            mpcFallback: mpc,
            checksummer: InstantChecksummer(),
            retryPolicy: retryPolicy
        )
        coordinator.setLocalIdentity(deviceID: UUID(), displayName: "🐱 Alice")
    }

    func makeTempFile(_ name: String, bytes: Int = 64) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("coord_test_\(UUID().uuidString)_\(name)")
        try? Data(repeating: 7, count: bytes).write(to: url)
        return url
    }

    /// Lets the coordinator's internal checksum/upload Tasks run.
    func settle(iterations: Int = 20) async {
        for _ in 0..<iterations { await Task.yield() }
    }
}

// MARK: - Tests

@MainActor
struct HTTPTransferSendCoordinatorTests {

    @Test func happyPath_allItemsDelivered() async throws {
        let harness = Harness()
        let fileURL = harness.makeTempFile("a.jpg")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var outcomes: [Result<Void, TransferSendError>] = []
        let files = [MediaFileToSend(url: fileURL, logicalIndex: 0, logicalTotal: 1, kind: .regular, suggestedName: "a")]
        let progresses = harness.coordinator.sendMedia(files, to: harness.peer, endpoint: harness.endpoint) { outcomes.append($0) }

        #expect(progresses.count == 1)
        await harness.settle()
        #expect(harness.uploadGate.requests.count == 1)

        let itemKey = harness.uploadGate.requests[0].itemKey
        harness.uploadGate.finish(itemKey, with: .delivered)
        await harness.settle()

        #expect(outcomes.count == 1)
        #expect((try? outcomes[0].get()) != nil)
        #expect(progresses[0].completedUnitCount == progresses[0].totalUnitCount)
    }

    @Test func headers_carrySameTransferIDAcrossBatchItems() async throws {
        let harness = Harness()
        let urls = [harness.makeTempFile("a.jpg"), harness.makeTempFile("b.jpg")]
        defer { urls.forEach { try? FileManager.default.removeItem(at: $0) } }

        let files = urls.enumerated().map { idx, url in
            MediaFileToSend(url: url, logicalIndex: idx, logicalTotal: 2, kind: .regular, suggestedName: nil)
        }
        _ = harness.coordinator.sendMedia(files, to: harness.peer, endpoint: harness.endpoint) { _ in }
        await harness.settle()

        let ids = Set(harness.uploadGate.requests.compactMap { $0.headers[TransferHTTPHeaders.transferID] })
        #expect(harness.uploadGate.requests.count == 2)
        #expect(ids.count == 1)
    }

    @Test func transportFailure_retriesThenFallsBackToMPC_withSameTransferID() async throws {
        let harness = Harness()
        let fileURL = harness.makeTempFile("doc.pdf")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var outcomes: [Result<Void, TransferSendError>] = []
        let files = [FileToSend(url: fileURL, name: "doc.pdf", index: 0, total: 1)]
        _ = harness.coordinator.sendFiles(files, to: harness.peer, endpoint: harness.endpoint) { outcomes.append($0) }
        await harness.settle()
        #expect(harness.uploadGate.requests.count == 1)
        let transferID = harness.uploadGate.requests[0].headers[TransferHTTPHeaders.transferID]!

        // Attempt 1 fails → retry scheduled (1ms backoff).
        harness.uploadGate.finish(harness.uploadGate.requests[0].itemKey, with: .transport("refused"))
        try await Task.sleep(for: .milliseconds(50))
        await harness.settle()
        #expect(harness.uploadGate.requests.count == 2, "second attempt expected after backoff")

        // Attempt 2 fails → maxAttempts (2) exhausted → MPC fallback.
        harness.uploadGate.finish(harness.uploadGate.requests[1].itemKey, with: .transport("refused"))
        await harness.settle()

        #expect(harness.mpc.fileCalls.count == 1)
        #expect(harness.mpc.fileCalls[0].transferID == transferID, "fallback must preserve the batch transferID")
        #expect(outcomes.isEmpty, "items handed to MPC are not terminal yet")

        harness.mpc.completeAll(with: .success(()))
        #expect(outcomes.count == 1)
        #expect((try? outcomes[0].get()) != nil)
    }

    @Test func non422ClientRejection_fallsBackImmediately() async throws {
        let harness = Harness()
        let fileURL = harness.makeTempFile("x.heic")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let files = [MediaFileToSend(url: fileURL, logicalIndex: 0, logicalTotal: 1, kind: .regular, suggestedName: nil)]
        _ = harness.coordinator.sendMedia(files, to: harness.peer, endpoint: harness.endpoint) { _ in }
        await harness.settle()

        harness.uploadGate.finish(harness.uploadGate.requests[0].itemKey, with: .rejected(status: 400))
        await harness.settle()

        #expect(harness.uploadGate.requests.count == 1, "400 must not be retried over HTTP")
        #expect(harness.mpc.mediaCalls.count == 1)
    }

    @Test func mpcUnavailable_reportsHonestFailure() async throws {
        let harness = Harness()
        let fileURL = harness.makeTempFile("y.mov")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        harness.mpc.available = false

        var outcomes: [Result<Void, TransferSendError>] = []
        let files = [MediaFileToSend(url: fileURL, logicalIndex: 0, logicalTotal: 1, kind: .regular, suggestedName: nil)]
        _ = harness.coordinator.sendMedia(files, to: harness.peer, endpoint: harness.endpoint) { outcomes.append($0) }
        await harness.settle()

        harness.uploadGate.finish(harness.uploadGate.requests[0].itemKey, with: .rejected(status: 404))
        await harness.settle()

        #expect(outcomes.count == 1)
        if case .failure(let error) = outcomes[0] {
            #expect(error == .peerUnreachable)
        } else {
            Issue.record("expected failure when both transports are unavailable")
        }
    }

    @Test func missingSourceFile_failsThatItemOnly() async throws {
        let harness = Harness()
        let goodURL = harness.makeTempFile("good.jpg")
        defer { try? FileManager.default.removeItem(at: goodURL) }
        let missingURL = FileManager.default.temporaryDirectory.appendingPathComponent("missing_\(UUID().uuidString).jpg")

        var outcomes: [Result<Void, TransferSendError>] = []
        let files = [
            MediaFileToSend(url: goodURL, logicalIndex: 0, logicalTotal: 2, kind: .regular, suggestedName: nil),
            MediaFileToSend(url: missingURL, logicalIndex: 1, logicalTotal: 2, kind: .regular, suggestedName: nil),
        ]
        _ = harness.coordinator.sendMedia(files, to: harness.peer, endpoint: harness.endpoint) { outcomes.append($0) }
        await harness.settle()

        #expect(harness.uploadGate.requests.count == 1, "only the existing file should upload")
        #expect(outcomes.count == 1)
        if case .failure(let error) = outcomes.first {
            #expect(error == .sourceFileMissing)
        } else {
            Issue.record("expected sourceFileMissing failure")
        }

        harness.uploadGate.finish(harness.uploadGate.requests[0].itemKey, with: .delivered)
        await harness.settle()
        #expect(outcomes.count == 2)
    }

    @Test func fallback_cancelsRemainingHTTPUploads() async throws {
        let harness = Harness(retryPolicy: TransferRetryPolicy(maxAttempts: 1))
        let urls = [harness.makeTempFile("a.jpg"), harness.makeTempFile("b.jpg")]
        defer { urls.forEach { try? FileManager.default.removeItem(at: $0) } }

        var outcomes: [Result<Void, TransferSendError>] = []
        let files = urls.enumerated().map { idx, url in
            MediaFileToSend(url: url, logicalIndex: idx, logicalTotal: 2, kind: .regular, suggestedName: nil)
        }
        _ = harness.coordinator.sendMedia(files, to: harness.peer, endpoint: harness.endpoint) { outcomes.append($0) }
        await harness.settle()
        #expect(harness.uploadGate.requests.count == 2)
        let transferID = harness.uploadGate.requests[0].headers[TransferHTTPHeaders.transferID]!

        // First item fails terminally (maxAttempts 1) → batch falls back;
        // the second item's in-flight upload must be cancelled and re-sent via MPC.
        harness.uploadGate.finish(harness.uploadGate.requests[0].itemKey, with: .transport("reset"))
        await harness.settle()

        #expect(harness.uploadGate.cancelledPrefixes == [transferID])
        #expect(harness.mpc.mediaCalls.count == 1)
        #expect(harness.mpc.mediaCalls[0].files.count == 2, "both undelivered items go to MPC")

        // The cancelled task's outcome must not double-drive the state machine.
        harness.uploadGate.finish(harness.uploadGate.requests[1].itemKey, with: .cancelled)
        await harness.settle()
        #expect(outcomes.isEmpty)

        harness.mpc.completeAll(with: .success(()))
        #expect(outcomes.count == 2)
    }
}
