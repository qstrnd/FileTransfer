import CryptoKit
import Foundation

/// Streams a file through CryptoKit's SHA-256 in 1 MiB chunks, off the main
/// actor, so hashing multi-hundred-MB videos neither spikes memory nor blocks UI.
nonisolated struct StreamingSHA256Hasher: Checksumming {
    private static let chunkSize = 1 << 20 // 1 MiB

    func sha256Hex(of fileURL: URL) async throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            guard let chunk = try handle.read(upToCount: Self.chunkSize), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
            await Task.yield() // Keep long hashes cooperative.
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
