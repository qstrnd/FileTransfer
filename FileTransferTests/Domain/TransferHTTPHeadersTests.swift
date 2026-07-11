import Foundation
import Testing
@testable import FileTransfer

struct TransferHTTPHeadersTests {

    private let sender = TransferHTTPHeaders.Sender(
        deviceID: UUID(uuidString: "6BB4B5A8-01BB-4E22-B7E2-0B0EEC5C5E0F")!,
        displayName: "🦅 Keen Eagle"
    )
    private let digest = String(repeating: "ab", count: 32)

    private func roundTrip(_ item: IncomingTransferItemInfo) -> (item: IncomingTransferItemInfo, sender: TransferHTTPHeaders.Sender, sha256Hex: String)? {
        TransferHTTPHeaders.decode(TransferHTTPHeaders.encode(item: item, sender: sender, sha256Hex: digest))
    }

    @Test func roundTrip_regularMedia() {
        let item = IncomingTransferItemInfo(
            transferID: "aabbccdd00112233aabbccdd00112233", index: 0, total: 3,
            payload: .media, kind: .regular, fileName: "IMG_1234", fileExtension: "heic"
        )
        let decoded = roundTrip(item)
        #expect(decoded?.item == item)
        #expect(decoded?.sender == sender)
        #expect(decoded?.sha256Hex == digest)
    }

    @Test func roundTrip_livePhotoVideo_withoutName() {
        let item = IncomingTransferItemInfo(
            transferID: "aabbccdd00112233aabbccdd00112233", index: 1, total: 2,
            payload: .media, kind: .livePhotoVideo, fileName: nil, fileExtension: "mov"
        )
        #expect(roundTrip(item)?.item == item)
    }

    @Test func roundTrip_file_withEmojiName() {
        let item = IncomingTransferItemInfo(
            transferID: "ffeeddcc00112233ffeeddcc00112233", index: 2, total: 5,
            payload: .file, kind: .regular, fileName: "Отчёт 📊 v2.pdf", fileExtension: "pdf"
        )
        #expect(roundTrip(item)?.item == item)
    }

    @Test func decode_isCaseInsensitiveOnHeaderNames() {
        let item = IncomingTransferItemInfo(
            transferID: "aabbccdd00112233aabbccdd00112233", index: 0, total: 1,
            payload: .media, kind: .regular, fileName: nil, fileExtension: "jpg"
        )
        let lowercased = Dictionary(
            TransferHTTPHeaders.encode(item: item, sender: sender, sha256Hex: digest)
                .map { ($0.key.lowercased(), $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        #expect(TransferHTTPHeaders.decode(lowercased)?.item == item)
    }

    @Test func decode_fileWithoutName_isRejected() {
        let item = IncomingTransferItemInfo(
            transferID: "aabbccdd00112233aabbccdd00112233", index: 0, total: 1,
            payload: .file, kind: .regular, fileName: "doc.pdf", fileExtension: "pdf"
        )
        var headers = TransferHTTPHeaders.encode(item: item, sender: sender, sha256Hex: digest)
        headers[TransferHTTPHeaders.nameHex] = nil
        #expect(TransferHTTPHeaders.decode(headers) == nil)
    }

    @Test func decode_rejectsMissingOrMalformedRequiredHeaders() {
        let item = IncomingTransferItemInfo(
            transferID: "aabbccdd00112233aabbccdd00112233", index: 0, total: 1,
            payload: .media, kind: .regular, fileName: nil, fileExtension: "jpg"
        )
        let valid = TransferHTTPHeaders.encode(item: item, sender: sender, sha256Hex: digest)

        for key in [TransferHTTPHeaders.transferID, TransferHTTPHeaders.payload,
                    TransferHTTPHeaders.index, TransferHTTPHeaders.total,
                    TransferHTTPHeaders.ext, TransferHTTPHeaders.sha256,
                    TransferHTTPHeaders.senderID, TransferHTTPHeaders.senderNameHex] {
            var broken = valid
            broken[key] = nil
            #expect(TransferHTTPHeaders.decode(broken) == nil, "missing \(key) must be rejected")
        }

        var badDigest = valid
        badDigest[TransferHTTPHeaders.sha256] = "abc123"   // not 64 hex chars
        #expect(TransferHTTPHeaders.decode(badDigest) == nil)

        var badIndex = valid
        badIndex[TransferHTTPHeaders.index] = "-1"
        #expect(TransferHTTPHeaders.decode(badIndex) == nil)

        var badUUID = valid
        badUUID[TransferHTTPHeaders.senderID] = "not-a-uuid"
        #expect(TransferHTTPHeaders.decode(badUUID) == nil)
    }

    @Test func decode_unknownKindFallsBackToRegular() {
        let item = IncomingTransferItemInfo(
            transferID: "aabbccdd00112233aabbccdd00112233", index: 0, total: 1,
            payload: .media, kind: .regular, fileName: nil, fileExtension: "jpg"
        )
        var headers = TransferHTTPHeaders.encode(item: item, sender: sender, sha256Hex: digest)
        headers[TransferHTTPHeaders.kind] = "someFutureKind"
        #expect(TransferHTTPHeaders.decode(headers)?.item.kind == .regular)
    }
}

struct HexCodingTests {

    @Test func roundTrip_ascii() {
        #expect(HexCoding.decode(HexCoding.encode("IMG_1234")) == "IMG_1234")
    }

    @Test func roundTrip_emoji() {
        #expect(HexCoding.decode(HexCoding.encode("🦅 Keen Eagle")) == "🦅 Keen Eagle")
    }

    @Test func decode_rejectsOddLength() {
        #expect(HexCoding.decode("abc") == nil)
    }

    @Test func decode_rejectsNonHex() {
        #expect(HexCoding.decode("zz") == nil)
    }
}
