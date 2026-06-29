import Foundation

/// Encodes/decodes the MPC resource name for a single file in a batch transfer.
///
/// Wire format: `file_<transferID>_<index>_<total>_<hexFilename>`
///
/// - `transferID`:   32-char UUID without hyphens (no underscores)
/// - `index`:        0-based position in the batch
/// - `total`:        number of files in the batch
/// - `hexFilename`:  lowercase hex-encoded UTF-8 of the full filename with extension
///
/// The "file_" prefix distinguishes this from `media_` resources so the two
/// decoders never collide in MCSession callbacks.
struct FileTransferResource: Sendable {
    nonisolated let transferID: String
    nonisolated let index: Int
    nonisolated let total: Int
    nonisolated let fileName: String

    nonisolated var name: String {
        "file_\(transferID)_\(index)_\(total)_\(hexEncode(fileName))"
    }

    nonisolated init(transferID: String, index: Int, total: Int, fileName: String) {
        self.transferID = transferID
        self.index = index
        self.total = total
        self.fileName = fileName.isEmpty ? "file" : fileName
    }

    nonisolated init?(parsing name: String) {
        let parts = name.components(separatedBy: "_")
        guard parts.count == 5,
              parts[0] == "file",
              !parts[1].isEmpty,
              let idx = Int(parts[2]),
              let ttl = Int(parts[3]),
              !parts[4].isEmpty,
              let fname = hexDecode(parts[4])
        else { return nil }
        transferID = parts[1]
        index = idx
        total = ttl
        fileName = fname
    }
}

private nonisolated func hexEncode(_ string: String) -> String {
    string.utf8.map { String(format: "%02x", $0) }.joined()
}

private nonisolated func hexDecode(_ hex: String) -> String? {
    guard hex.count % 2 == 0 else { return nil }
    var bytes: [UInt8] = []
    bytes.reserveCapacity(hex.count / 2)
    var i = hex.startIndex
    while i < hex.endIndex {
        let j = hex.index(i, offsetBy: 2)
        guard let byte = UInt8(hex[i..<j], radix: 16) else { return nil }
        bytes.append(byte)
        i = j
    }
    return String(bytes: bytes, encoding: .utf8)
}
