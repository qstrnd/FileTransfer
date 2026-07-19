import UIKit
import UniformTypeIdentifiers

/// Reads and classifies the system pasteboard for sharing.
///
/// Availability is checked with the pasteboard's *detection* properties
/// (`hasStrings`/`hasImages`/…), which — unlike reading the actual contents —
/// don't trigger the system's "pasted from" disclosure or require permission.
/// The contents are only read in `read()`, on an explicit user tap.
enum PasteboardShareImporter {

    /// Permission-free, disclosure-free "is there anything to share?" check.
    static var hasContent: Bool {
        let pb = UIPasteboard.general
        return pb.hasStrings || pb.hasImages || pb.hasURLs || pb.hasColors || pb.numberOfItems > 0
    }

    /// Reads the pasteboard and classifies it. Reading here is what surfaces the
    /// one-time paste banner, so it's called only when the user taps Pasteboard.
    /// Returns nil if nothing usable could be extracted.
    static func read() -> PasteboardShareContent? {
        let pb = UIPasteboard.general
        let dir = makeTempDirectory()

        // 1. Images only → treat as images.
        if let images = pb.images, !images.isEmpty {
            let urls = images.enumerated().compactMap { index, image in
                write(image: image, index: index, in: dir)
            }
            if !urls.isEmpty { return .images(urls) }
        }

        // 2. Plain text (including a copied URL string) → text.
        if pb.hasStrings, let string = pb.string,
           !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text(string)
        }

        // 3. Anything else / a mix of unrelated data → files.
        let files = writeItemsAsFiles(pb, in: dir)
        return files.isEmpty ? nil : .files(files)
    }

    /// Removes the temp files backing a previously-read content (call on cancel).
    static func cleanUp(_ content: PasteboardShareContent) {
        let urls = content.temporaryURLs
        guard let dir = urls.first?.deletingLastPathComponent() else { return }
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Writing temp files

    private static func write(image: UIImage, index: Int, in dir: URL) -> URL? {
        // PNG preserves transparency and lossless quality for screenshots/graphics.
        guard let data = image.pngData() else { return nil }
        let url = dir.appendingPathComponent("image-\(index + 1).png")
        do { try data.write(to: url); return url } catch { return nil }
    }

    private static func writeItemsAsFiles(_ pb: UIPasteboard, in dir: URL) -> [PasteboardShareFile] {
        pb.items.enumerated().compactMap { index, item in
            guard let (type, data) = bestRepresentation(of: item) else { return nil }
            let ext = type?.preferredFilenameExtension ?? "dat"
            let fileName = "Item \(index + 1).\(ext)"
            let url = dir.appendingPathComponent("item-\(index + 1).\(ext)")
            do {
                try data.write(to: url)
                return PasteboardShareFile(url: url, name: fileName, systemImage: symbol(for: type))
            } catch {
                return nil
            }
        }
    }

    /// Picks the richest data-bearing representation from one pasteboard item.
    /// Prefers a concrete UTType with bytes over a bare string.
    private static func bestRepresentation(of item: [String: Any]) -> (UTType?, Data)? {
        var fallback: (UTType?, Data)?
        for (identifier, value) in item {
            let type = UTType(identifier)
            guard let data = data(from: value) else { continue }
            // Prefer a non-plain-text type when available; keep text as a fallback.
            if let type, !type.conforms(to: .plainText) {
                return (type, data)
            }
            if fallback == nil { fallback = (type, data) }
        }
        return fallback
    }

    private static func data(from value: Any) -> Data? {
        switch value {
        case let data as Data:     data
        case let string as String: string.data(using: .utf8)
        case let url as URL:       url.isFileURL ? try? Data(contentsOf: url) : url.absoluteString.data(using: .utf8)
        case let image as UIImage: image.pngData()
        default:                   nil
        }
    }

    private static func symbol(for type: UTType?) -> String {
        guard let type else { return "doc" }
        if type.conforms(to: .image)         { return "photo" }
        if type.conforms(to: .audiovisualContent) { return "video" }
        if type.conforms(to: .pdf)           { return "doc.richtext" }
        if type.conforms(to: .text)          { return "doc.text" }
        if type.conforms(to: .archive)       { return "doc.zipper" }
        return "doc"
    }

    private static func makeTempDirectory() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PasteboardShare", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
