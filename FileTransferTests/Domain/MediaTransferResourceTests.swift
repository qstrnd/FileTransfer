import Testing
@testable import FileTransfer

struct MediaTransferResourceTests {

    // MARK: - Encoding

    @Test func encodedNameFormat() {
        let r = MediaTransferResource(transferID: "ABC123", index: 0, total: 3, fileExtension: "mp4")
        #expect(r.name == "media_ABC123_0_3_mp4")
    }

    @Test func normalizesExtensionToLowercase() {
        let r = MediaTransferResource(transferID: "X", index: 0, total: 1, fileExtension: "HEIC")
        #expect(r.fileExtension == "heic")
        #expect(r.name == "media_X_0_1_heic")
    }

    @Test func emptyExtensionFallsBackToBin() {
        let r = MediaTransferResource(transferID: "X", index: 0, total: 1, fileExtension: "")
        #expect(r.fileExtension == "bin")
    }

    // MARK: - Decoding

    @Test func parsesWellFormedName() {
        let r = MediaTransferResource(parsing: "media_ABC123_1_4_jpg")
        #expect(r != nil)
        #expect(r?.transferID == "ABC123")
        #expect(r?.index == 1)
        #expect(r?.total == 4)
        #expect(r?.fileExtension == "jpg")
    }

    @Test func roundTrip() {
        let original = MediaTransferResource(
            transferID: "ABCDEF123456789",
            index: 2, total: 5, fileExtension: "heic"
        )
        let parsed = MediaTransferResource(parsing: original.name)
        #expect(parsed?.transferID == original.transferID)
        #expect(parsed?.index == original.index)
        #expect(parsed?.total == original.total)
        #expect(parsed?.fileExtension == original.fileExtension)
    }

    // MARK: - Invalid inputs

    @Test func rejectsOldFourComponentFormat() {
        #expect(MediaTransferResource(parsing: "media_ABC123_0_3") == nil)
    }

    @Test func rejectsWrongPrefix() {
        #expect(MediaTransferResource(parsing: "image_ABC123_0_3_jpg") == nil)
    }

    @Test func rejectsNonIntegerIndex() {
        #expect(MediaTransferResource(parsing: "media_ABC123_x_3_jpg") == nil)
    }

    @Test func rejectsNonIntegerTotal() {
        #expect(MediaTransferResource(parsing: "media_ABC123_0_y_jpg") == nil)
    }

    @Test func rejectsEmptyTransferID() {
        #expect(MediaTransferResource(parsing: "media__0_3_jpg") == nil)
    }

    @Test func rejectsEmptyExtensionInParsing() {
        #expect(MediaTransferResource(parsing: "media_ABC123_0_3_") == nil)
    }

    @Test func rejectsTooManyComponents() {
        #expect(MediaTransferResource(parsing: "media_ABC_0_3_jpg_extra") == nil)
    }
}
