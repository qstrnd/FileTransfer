import Foundation
import UniformTypeIdentifiers

/// Materialises drag-and-dropped items into the shapes the send flows accept:
/// images and movies become `MediaItem`s, everything else becomes file URLs.
///
/// Each provider is copied into its own temp directory so the send stack owns a
/// stable file for the transfer's lifetime, and documents keep their original
/// filename (the send path surfaces it to the receiver).
enum DroppedItemImporter {

    struct Import {
        var media: [MediaItem] = []
        var files: [URL] = []
        var isEmpty: Bool { media.isEmpty && files.isEmpty }
    }

    static func load(_ providers: [NSItemProvider]) async -> Import {
        var result = Import()
        for provider in providers {
            let name = provider.suggestedName
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                let typeID = MediaItemLoader.preferredImageTypeIdentifier(among: provider.registeredTypeIdentifiers)
                if let url = await copyFile(from: provider, typeIdentifier: typeID, suggestedName: name, preserveName: false) {
                    result.media.append(MediaItem(fileURL: url, isVideo: false, livePhotoVideoURL: nil, fileName: name))
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                if let url = await copyFile(from: provider, typeIdentifier: UTType.movie.identifier, suggestedName: name, preserveName: false) {
                    result.media.append(MediaItem(fileURL: url, isVideo: true, livePhotoVideoURL: nil, fileName: name))
                }
            } else if let typeID = provider.registeredTypeIdentifiers.first {
                if let url = await copyFile(from: provider, typeIdentifier: typeID, suggestedName: name, preserveName: true) {
                    result.files.append(url)
                }
            }
        }
        return result
    }

    /// Copies the provider's file representation into a unique temp directory.
    /// `preserveName` keeps the original filename (for documents); otherwise the
    /// file is named by UUID (media carries its display name separately).
    private static func copyFile(
        from provider: NSItemProvider,
        typeIdentifier: String,
        suggestedName: String?,
        preserveName: Bool
    ) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { srcURL, _ in
                guard let srcURL else {
                    continuation.resume(returning: nil)
                    return
                }
                let ext = srcURL.pathExtension
                let dir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("drop_\(UUID().uuidString)")
                let fileName: String
                if preserveName {
                    let base = suggestedName ?? srcURL.deletingPathExtension().lastPathComponent
                    fileName = ext.isEmpty ? base : "\(base).\(ext)"
                } else {
                    fileName = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
                }
                let dest = dir.appendingPathComponent(fileName)
                do {
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: srcURL, to: dest)
                    continuation.resume(returning: dest)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
