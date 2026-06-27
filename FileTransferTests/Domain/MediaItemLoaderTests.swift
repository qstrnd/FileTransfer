import Testing
import UniformTypeIdentifiers
@testable import FileTransfer

struct MediaItemLoaderTests {

    // MARK: - preferredImageTypeIdentifier

    @Test func prefersHEICOverJPEG() {
        let ids = [UTType.heic.identifier, UTType.jpeg.identifier, UTType.image.identifier]
        let result = MediaItemLoader.preferredImageTypeIdentifier(among: ids)
        #expect(result == UTType.heic.identifier)
    }

    @Test func prefersJPEGWhenNoHEIC() {
        let ids = [UTType.jpeg.identifier, UTType.image.identifier]
        let result = MediaItemLoader.preferredImageTypeIdentifier(among: ids)
        #expect(result == UTType.jpeg.identifier)
    }

    @Test func prefersPNGWhenNoHEICOrJPEG() {
        let ids = [UTType.png.identifier, UTType.image.identifier]
        let result = MediaItemLoader.preferredImageTypeIdentifier(among: ids)
        #expect(result == UTType.png.identifier)
    }

    @Test func fallsBackToGenericImageForUnknownType() {
        let result = MediaItemLoader.preferredImageTypeIdentifier(among: ["public.data"])
        #expect(result == UTType.image.identifier)
    }

    @Test func fallsBackToGenericImageForEmptyList() {
        let result = MediaItemLoader.preferredImageTypeIdentifier(among: [])
        #expect(result == UTType.image.identifier)
    }

    @Test func genericImageIdentifierMatchesGenericCandidate() {
        // A provider that only offers "public.image" should get "public.image" back.
        let ids = [UTType.image.identifier]
        let result = MediaItemLoader.preferredImageTypeIdentifier(among: ids)
        #expect(result == UTType.image.identifier)
    }

    // MARK: - preferredImageTypes ordering

    @Test func preferredTypesListIsInDescendingSpecificity() {
        let types = MediaItemLoader.preferredImageTypes
        let heicIdx = types.firstIndex(of: .heic)
        let jpegIdx = types.firstIndex(of: .jpeg)
        let pngIdx  = types.firstIndex(of: .png)
        let imageIdx = types.firstIndex(of: .image)
        #expect(heicIdx != nil && jpegIdx != nil && pngIdx != nil && imageIdx != nil)
        #expect(heicIdx! < jpegIdx!)
        #expect(jpegIdx! < pngIdx!)
        #expect(pngIdx!  < imageIdx!)
    }

    @Test func genericImageIsLastFallback() {
        #expect(MediaItemLoader.preferredImageTypes.last == .image)
    }
}
