import Foundation

/// Computes content digests for transfer integrity verification.
protocol Checksumming: Sendable {
    /// Lowercase hex SHA-256 of the file's contents, computed by streaming
    /// (implementations must not load the whole file into memory).
    func sha256Hex(of fileURL: URL) async throws -> String
}
