import PhotosUI
import UniformTypeIdentifiers

/// Loads a MediaItem from a PHPickerResult, preserving the original file format.
///
/// Images are loaded via `loadFileRepresentation` rather than `loadObject(ofClass:UIImage.self)`,
/// so the bytes sent over MPC are the original HEIC/JPEG/PNG/etc. file with no re-encoding.
enum MediaItemLoader {

    /// Image UTTypes tried in descending specificity. The first one the provider
    /// supports wins, giving us the original file format (e.g. HEIC) instead of
    /// a decoded/re-compressed copy.
    // nonisolated so tests (and nonisolated callers) can access without main-actor dispatch.
    nonisolated static let preferredImageTypes: [UTType] = [
        .heic, .jpeg, .png, .gif, .tiff, .webP, .image,
    ]

    // MARK: - Public

    static func load(from result: PHPickerResult) async -> MediaItem? {
        let provider = result.itemProvider
        // Check video first: some providers may conform to both movie and image.
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            return await copyFile(from: provider, typeIdentifier: UTType.movie.identifier, isVideo: true)
        } else {
            let typeID = preferredImageTypeIdentifier(among: provider.registeredTypeIdentifiers)
            return await copyFile(from: provider, typeIdentifier: typeID, isVideo: false)
        }
    }

    /// Returns the best type identifier among `registeredIdentifiers` for preserving
    /// the original image format. `internal` (not `private`) so it can be unit-tested.
    nonisolated static func preferredImageTypeIdentifier(among registeredIdentifiers: [String]) -> String {
        for candidate in preferredImageTypes {
            let match = registeredIdentifiers.contains {
                UTType($0)?.conforms(to: candidate) == true
            }
            if match { return candidate.identifier }
        }
        return UTType.image.identifier
    }

    // MARK: - Private

    private static func copyFile(
        from provider: NSItemProvider,
        typeIdentifier: String,
        isVideo: Bool
    ) async -> MediaItem? {
        await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                guard let srcURL = url, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                let ext = srcURL.pathExtension.isEmpty
                    ? (isVideo ? "mov" : "jpg")
                    : srcURL.pathExtension.lowercased()
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + "." + ext)
                do {
                    try FileManager.default.copyItem(at: srcURL, to: dest)
                    continuation.resume(returning: MediaItem(fileURL: dest, isVideo: isVideo))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
