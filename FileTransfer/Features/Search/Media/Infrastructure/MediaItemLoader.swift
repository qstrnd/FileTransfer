import PhotosUI
import UniformTypeIdentifiers

/// Loads a MediaItem from a PHPickerResult, preserving the original file format
/// and extracting Live Photo pairs.
///
/// Detection order:
///   1. Live Photo  — provider has both an image type AND com.apple.quicktime-movie
///   2. Regular video — provider has a movie type only
///   3. Regular image — tries image types in descending specificity
///
/// Why this detection?
/// `hasItemConformingToTypeIdentifier(UTType.livePhoto)` is unreliable because
/// UTType.livePhoto is the PHLivePhoto *object* type, not a file-representation type.
/// PHPickerResult providers filtered by .images expose `com.apple.quicktime-movie`
/// for the LP companion but not necessarily `com.apple.live-photo`. Checking for
/// the co-presence of an image type and `com.apple.quicktime-movie` is the reliable
/// signal — that combination is only present for Live Photos.
enum MediaItemLoader {

    /// Image UTTypes tried in descending specificity so we get the original
    /// encoded file (HEIC/JPEG/…) rather than a decoded or re-compressed copy.
    nonisolated static let preferredImageTypes: [UTType] = [
        .heic, .jpeg, .png, .gif, .tiff, .webP, .image,
    ]

    // MARK: - Public

    static func load(from result: PHPickerResult) async -> MediaItem? {
        let provider = result.itemProvider
        let suggestedName = provider.suggestedName
        let registered = provider.registeredTypeIdentifiers

        let hasImageType = registered.contains { UTType($0)?.conforms(to: .image) == true }
        let hasMovieType = registered.contains { UTType($0)?.conforms(to: .movie) == true }

        // Live Photo: provides BOTH a still image representation AND a QuickTime companion.
        if hasImageType && hasMovieType {
            return await loadLivePhoto(from: provider, suggestedName: suggestedName)
        } else if hasMovieType {
            guard let url = await loadFile(from: provider, typeIdentifier: UTType.movie.identifier) else { return nil }
            return MediaItem(fileURL: url, isVideo: true, livePhotoVideoURL: nil, fileName: suggestedName)
        } else {
            let typeID = preferredImageTypeIdentifier(among: registered)
            guard let url = await loadFile(from: provider, typeIdentifier: typeID) else { return nil }
            return MediaItem(fileURL: url, isVideo: false, livePhotoVideoURL: nil, fileName: suggestedName)
        }
    }

    /// Returns the best type identifier among `registeredIdentifiers` for preserving
    /// the original image format. `internal` so it can be unit-tested.
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

    private static func loadLivePhoto(from provider: NSItemProvider, suggestedName: String?) async -> MediaItem? {
        let imageTypeID = preferredImageTypeIdentifier(among: provider.registeredTypeIdentifiers)
        let stillURL = await loadFile(from: provider, typeIdentifier: imageTypeID)

        // The companion is registered as com.apple.quicktime-movie (specific).
        // loadFileRepresentation needs the exact registered identifier, not a supertype.
        let videoURL = await loadFile(from: provider, typeIdentifier: UTType.quickTimeMovie.identifier)

        guard let stillURL else { return nil }
        // If the companion load failed for any reason, fall back to a plain still.
        return MediaItem(fileURL: stillURL, isVideo: false, livePhotoVideoURL: videoURL, fileName: suggestedName)
    }

    /// Copies the provider's file representation to a stable temp URL and returns it.
    /// The `srcURL` given to the completion handler is only valid during the callback.
    private static func loadFile(from provider: NSItemProvider, typeIdentifier: String) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                guard let srcURL = url, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                let ext = srcURL.pathExtension.isEmpty
                    ? (typeIdentifier == UTType.quickTimeMovie.identifier ? "mov" : "jpg")
                    : srcURL.pathExtension.lowercased()
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + "." + ext)
                do {
                    try FileManager.default.copyItem(at: srcURL, to: dest)
                    continuation.resume(returning: dest)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
