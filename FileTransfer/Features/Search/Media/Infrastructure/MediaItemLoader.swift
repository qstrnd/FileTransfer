import Photos
import PhotosUI
import UniformTypeIdentifiers
import OSLog

/// Loads a MediaItem from a PHPickerResult, preserving the original file format
/// and extracting Live Photo pairs.
///
/// Detection order:
///   1. Live Photo — provider exposes "com.apple.live-photo" OR has both an image
///      type and a movie type in registeredTypeIdentifiers
///   2. Regular video
///   3. Regular image
///
/// LP extraction tries two paths:
///   A. loadFileRepresentation for still + UTType.quickTimeMovie companion (fast)
///   B. loadObject(PHLivePhoto) + PHAssetResourceManager.writeData (reliable fallback)
///
/// Path B is the Apple-recommended approach for PHPickerResult and works regardless
/// of which type identifiers the provider exposes for the companion video.
enum MediaItemLoader {

    nonisolated private static let log = Logger(
        subsystem: "com.qstrnd.FileTransfer", category: "MediaItemLoader"
    )

    /// Image UTTypes tried in descending specificity.
    nonisolated static let preferredImageTypes: [UTType] = [
        .heic, .jpeg, .png, .gif, .tiff, .webP, .image,
    ]

    // MARK: - Public

    static func load(from result: PHPickerResult) async -> MediaItem? {
        let provider = result.itemProvider
        let suggestedName = provider.suggestedName
        let registered = provider.registeredTypeIdentifiers

        log.debug("load — suggestedName=\(suggestedName ?? "nil", privacy: .public) registered=\(registered.joined(separator: ","), privacy: .public)")

        let hasLivePhotoType = registered.contains("com.apple.live-photo") || provider.canLoadObject(ofClass: PHLivePhoto.self)
        let hasImageType = registered.contains { UTType($0)?.conforms(to: .image) == true }
        let hasMovieType = registered.contains { UTType($0)?.conforms(to: .movie) == true }

        if hasLivePhotoType || (hasImageType && hasMovieType) {
            log.debug("load — LP branch (hasLivePhotoType=\(hasLivePhotoType) hasImage=\(hasImageType) hasMovie=\(hasMovieType))")
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

    nonisolated static func preferredImageTypeIdentifier(among registeredIdentifiers: [String]) -> String {
        for candidate in preferredImageTypes {
            if registeredIdentifiers.contains(where: { UTType($0)?.conforms(to: candidate) == true }) {
                return candidate.identifier
            }
        }
        return UTType.image.identifier
    }

    // MARK: - Live Photo

    private static func loadLivePhoto(from provider: NSItemProvider, suggestedName: String?) async -> MediaItem? {
        let imageTypeID = preferredImageTypeIdentifier(among: provider.registeredTypeIdentifiers)
        let stillURL = await loadFile(from: provider, typeIdentifier: imageTypeID)
        var videoURL = await loadFile(from: provider, typeIdentifier: UTType.quickTimeMovie.identifier)

        log.debug("LP path A — still=\(stillURL?.lastPathComponent ?? "nil", privacy: .public) video=\(videoURL?.lastPathComponent ?? "nil", privacy: .public)")

        // 1. Ensure the still image actually exists and has data
        if let still = stillURL, isFileValid(still) {
            
            // 2. Check Path A companion video. If missing or 0 bytes, try Path B.
            if videoURL == nil || !isFileValid(videoURL!) {
                log.debug("LP path A — companion nil or invalid; trying path B (PHAssetResourceManager)")
                
                if let companion = await loadLPCompanionViaObject(from: provider), isFileValid(companion) {
                    log.debug("LP path B companion=\(companion.lastPathComponent, privacy: .public)")
                    videoURL = companion
                } else {
                    log.debug("LP path B companion failed too. Downgrading to standard still image.")
                    // Downgrade to standard image if the companion is entirely unrecoverable
                    return MediaItem(fileURL: still, isVideo: false, livePhotoVideoURL: nil, fileName: suggestedName)
                }
            }
            
            // 3. Deep Validation: Ensure the files form a recognized Live Photo pair
            let validVideo = videoURL!
            if await isValidLivePhotoPair(stillURL: still, videoURL: validVideo) {
                return MediaItem(fileURL: still, isVideo: false, livePhotoVideoURL: validVideo, fileName: suggestedName)
            } else {
                log.debug("Files exist but do not form a valid Live Photo pair. Downgrading to still image.")
                return MediaItem(fileURL: still, isVideo: false, livePhotoVideoURL: nil, fileName: suggestedName)
            }
        }

        // Path A failed entirely (still is nil or corrupt) — fall back to PHLivePhoto object approach.
        log.debug("LP path A failed entirely; falling back to path B (PHLivePhoto object)")
        return await loadLivePhotoViaObject(from: provider, suggestedName: suggestedName)
    }
    
    /// Checks if a file exists at the URL and has a non-zero size.
    private static func isFileValid(_ url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int64,
              fileSize > 0 else {
            return false
        }
        return true
    }
    
    /// Verifies that the Photos framework accepts the two URLs as a valid Live Photo.
    private static func isValidLivePhotoPair(stillURL: URL, videoURL: URL) async -> Bool {
        return await withCheckedContinuation { continuation in
            // Class wrapper to safely track state and prevent double-resume crashes
            class ContinuationState { var isResumed = false }
            let state = ContinuationState()
            
            PHLivePhoto.request(
                withResourceFileURLs: [stillURL, videoURL],
                placeholderImage: nil,
                targetSize: .zero,
                contentMode: .aspectFit
            ) { livePhoto, info in
                let isDegraded = info[PHLivePhotoInfoIsDegradedKey] as? Bool ?? false
                
                // We only care about the final, non-degraded result
                if !isDegraded && !state.isResumed {
                    state.isResumed = true
                    let error = info[PHLivePhotoInfoErrorKey] as? Error
                    
                    // Valid if we get an object back and no errors
                    continuation.resume(returning: livePhoto != nil && error == nil)
                }
            }
        }
    }

    /// Extracts both LP components via `PHLivePhoto` + `PHAssetResourceManager`.
    /// This is the Apple-documented approach for PHPickerResult and does not require
    /// full Photos library authorisation beyond what the picker grants.
    private static func loadLivePhotoViaObject(
        from provider: NSItemProvider, suggestedName: String?
    ) async -> MediaItem? {
        guard let livePhoto = await loadPHLivePhoto(from: provider) else {
            log.debug("LP path B — PHLivePhoto load failed")
            return nil
        }
        let resources = PHAssetResource.assetResources(for: livePhoto)
        log.debug("LP path B resources=\(resources.map { "\($0.type.rawValue):\($0.originalFilename)" }.joined(separator: ","), privacy: .public)")

        guard let imageRes = resources.first(where: { $0.type == .photo }) else { return nil }
        let videoRes = resources.first(where: { $0.type == .pairedVideo })

        let stillExt = (imageRes.originalFilename as NSString).pathExtension.lowercased()
        let stillDest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "." + (stillExt.isEmpty ? "heic" : stillExt))

        guard await writeResource(imageRes, to: stillDest) else {
            log.debug("LP path B — still write failed")
            return nil
        }

        var videoDest: URL?
        if let videoRes {
            let videoExt = (videoRes.originalFilename as NSString).pathExtension.lowercased()
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "." + (videoExt.isEmpty ? "mov" : videoExt))
            if await writeResource(videoRes, to: dest) { videoDest = dest }
            else { log.debug("LP path B — companion write failed") }
        }

        return MediaItem(fileURL: stillDest, isVideo: false, livePhotoVideoURL: videoDest, fileName: suggestedName)
    }

    /// Extracts just the LP companion video via PHAssetResourceManager.
    /// Used when path A already gave us the still but not the companion.
    private static func loadLPCompanionViaObject(from provider: NSItemProvider) async -> URL? {
        guard let livePhoto = await loadPHLivePhoto(from: provider) else { return nil }
        let resources = PHAssetResource.assetResources(for: livePhoto)
        guard let videoRes = resources.first(where: { $0.type == .pairedVideo }) else { return nil }
        let ext = (videoRes.originalFilename as NSString).pathExtension.lowercased()
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "." + (ext.isEmpty ? "mov" : ext))
        return await writeResource(videoRes, to: dest) ? dest : nil
    }

    // MARK: - Helpers

    private static func loadPHLivePhoto(from provider: NSItemProvider) async -> PHLivePhoto? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: PHLivePhoto.self) { object, error in
                if let error { Logger(subsystem: "com.qstrnd.FileTransfer", category: "MediaItemLoader")
                    .debug("loadPHLivePhoto error: \(error.localizedDescription, privacy: .public)") }
                continuation.resume(returning: object as? PHLivePhoto)
            }
        }
    }

    private static func writeResource(_ resource: PHAssetResource, to url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true
            PHAssetResourceManager.default().writeData(for: resource, toFile: url, options: options) { error in
                continuation.resume(returning: error == nil)
            }
        }
    }

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
