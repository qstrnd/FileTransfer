import Foundation

/// Caches attachment files at `Library/Application Support/TransferAttachments/<recordID>/`.
/// Each record gets its own subdirectory so filenames from different sessions never collide.
/// @unchecked Sendable: FileManager operations are thread-safe per Apple docs.
final class TransferAttachmentCache: AttachmentCacheGate, @unchecked Sendable {

    private let root: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        root = appSupport.appendingPathComponent("TransferAttachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    // MARK: - AttachmentCacheGate

    func cache(_ urls: [URL], names: [String?], forRecord id: UUID) async -> [URL] {
        let dir = root.appendingPathComponent(id.uuidString, isDirectory: true)
        return await Task.detached(priority: .utility) { [dir] in
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            // Pre-pass: count nil-name items per extension to decide number suffixes.
            var extTotal: [String: Int] = [:]
            for (url, name) in zip(urls, names) where (name ?? "").isEmpty {
                let ext = url.pathExtension.lowercased().isEmpty ? "bin" : url.pathExtension.lowercased()
                extTotal[ext, default: 0] += 1
            }
            var extCounter: [String: Int] = [:]

            var result: [URL] = []
            for (src, providedName) in zip(urls, names) {
                let desiredName: String
                if let n = providedName, !n.isEmpty {
                    desiredName = n
                } else {
                    // Generate a simple human-readable fallback name.
                    let ext = src.pathExtension.lowercased()
                    let base = Self.fallbackBase(for: ext)
                    let total = extTotal[ext.isEmpty ? "bin" : ext, default: 1]
                    let counter = (extCounter[ext, default: 0]) + 1
                    extCounter[ext] = counter
                    let stem = total == 1 ? base : "\(base)\(counter)"
                    desiredName = ext.isEmpty ? stem : "\(stem).\(ext)"
                }

                var dst = dir.appendingPathComponent(desiredName)
                if FileManager.default.fileExists(atPath: dst.path(percentEncoded: false)) {
                    let ext = dst.pathExtension
                    let stem = dst.deletingPathExtension().lastPathComponent
                    let suffix = String(UUID().uuidString.prefix(6))
                    let unique = ext.isEmpty ? "\(stem)-\(suffix)" : "\(stem)-\(suffix).\(ext)"
                    dst = dir.appendingPathComponent(unique)
                }

                do {
                    try FileManager.default.copyItem(at: src, to: dst)
                    result.append(dst)
                } catch {
                    // Skip files whose security scope has expired or that are unreadable.
                }
            }
            return result
        }.value
    }

    func fileBytes(for urls: [URL]) -> Int64 {
        urls.reduce(into: 0 as Int64) { acc, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            acc += Int64(size)
        }
    }

    func delete(recordID id: UUID) {
        let dir = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Private

    private nonisolated static func fallbackBase(for ext: String) -> String {
        switch ext {
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "tif", "tiff", "bmp", "webp":
            return "image"
        case "mp4", "mov", "m4v", "avi", "mkv":
            return "video"
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key":
            return "document"
        case "zip", "rar", "7z", "tar", "gz":
            return "archive"
        default:
            return "file"
        }
    }
}
