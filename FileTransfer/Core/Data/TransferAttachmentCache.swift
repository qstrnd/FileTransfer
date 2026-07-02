import Foundation

/// Caches attachment files at `Library/Caches/TransferAttachments/<recordID>/`.
/// Original filenames are preserved where possible; index suffixes resolve collisions.
/// @unchecked Sendable: FileManager operations are thread-safe per Apple docs.
final class TransferAttachmentCache: AttachmentCacheGate, @unchecked Sendable {

    private let root: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        root = appSupport.appendingPathComponent("TransferAttachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    // MARK: - AttachmentCacheGate

    func cache(_ urls: [URL], forRecord id: UUID) async -> [URL] {
        let dir = root.appendingPathComponent(id.uuidString, isDirectory: true)
        return await Task.detached(priority: .utility) { [dir] in
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            var result: [URL] = []
            for (idx, src) in urls.enumerated() {
                var name = src.lastPathComponent.isEmpty ? "attachment-\(idx)" : src.lastPathComponent
                var dst = dir.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: dst.path(percentEncoded: false)) {
                    let ext = src.pathExtension
                    let base = src.deletingPathExtension().lastPathComponent
                    name = ext.isEmpty ? "\(base)-\(idx)" : "\(base)-\(idx).\(ext)"
                    dst = dir.appendingPathComponent(name)
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
}
