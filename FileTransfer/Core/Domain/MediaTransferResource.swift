import Foundation

/// Encodes and decodes the MultipeerConnectivity resource name for a single media file.
///
/// Wire format:
///   `media_<transferID>_<logicalIndex>_<logicalTotal>_<ext>[_<kind>][~<hexName>]`
///
/// - `transferID`   : UUID with hyphens stripped (32 hex chars, no underscores)
/// - `logicalIndex` : 0-based position of the *user-visible* item; LP still and its
///                    companion video share the same index
/// - `logicalTotal` : number of user-visible items (not file count)
/// - `ext`          : lowercase file extension without dot ("heic", "mov", …)
/// - `kind`         : optional 6th underscore component — "lp" (Live Photo still),
///                    "lpv" (Live Photo companion video); absent = regular
/// - `hexName`      : optional suffix after `~`; lowercase hex-encoded UTF-8 of the
///                    original base filename (no extension, e.g. "IMG_1234")
///
/// Receivers that pre-date Live Photo support parse only the 5-component prefix and
/// treat the item as a regular file — backwards compatible.
struct MediaTransferResource: Sendable {
    nonisolated let transferID: String
    nonisolated let index: Int       // logicalIndex
    nonisolated let total: Int       // logicalTotal
    nonisolated let fileExtension: String
    nonisolated let kind: MediaFileKind
    nonisolated let fileName: String? // decoded suggestedName, nil if absent

    // MARK: - Wire-format name

    nonisolated var name: String {
        var base = "media_\(transferID)_\(index)_\(total)_\(fileExtension)"
        if kind != .regular { base += "_\(kind.rawValue)" }
        if let fileName { base += "~\(hexEncode(fileName))" }
        return base
    }

    // MARK: - Init from a file-to-send

    nonisolated init(from file: MediaFileToSend) {
        self.transferID = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        self.index = file.logicalIndex
        self.total = file.logicalTotal
        self.fileExtension = file.url.pathExtension.isEmpty
            ? (file.kind == .livePhotoVideo ? "mov" : "jpg")
            : file.url.pathExtension.lowercased()
        self.kind = file.kind
        self.fileName = file.suggestedName
    }

    // MARK: - Init with explicit transferID (used by MultipeerNearbyService)

    nonisolated init(
        transferID: String,
        from file: MediaFileToSend
    ) {
        self.transferID = transferID
        self.index = file.logicalIndex
        self.total = file.logicalTotal
        self.fileExtension = file.url.pathExtension.isEmpty
            ? (file.kind == .livePhotoVideo ? "mov" : "jpg")
            : file.url.pathExtension.lowercased()
        self.kind = file.kind
        self.fileName = file.suggestedName
    }

    /// Returns `nil` if `name` doesn't meet the minimum 5-component format.
    nonisolated init?(parsing name: String) {
        // Split off optional filename suffix first (~ is not valid in iOS filenames
        // and not a base64/hex char, so it's a safe separator).
        let tildeParts = name.components(separatedBy: "~")
        let mainPart = tildeParts[0]
        let hexName = tildeParts.count > 1 ? tildeParts[1] : nil

        let parts = mainPart.components(separatedBy: "_")
        // parts: [0]=media [1]=transferID [2]=index [3]=total [4]=ext [5?]=kind
        guard parts.count >= 5,
              parts[0] == "media",
              !parts[1].isEmpty,
              let idx = Int(parts[2]),
              let ttl = Int(parts[3]),
              !parts[4].isEmpty
        else { return nil }

        transferID = parts[1]
        index = idx
        total = ttl
        fileExtension = parts[4]
        kind = parts.count >= 6 ? (MediaFileKind(rawValue: parts[5]) ?? .regular) : .regular
        fileName = hexName.flatMap { hexDecode($0) }
    }
}

// MARK: - Hex encoding helpers (private to this file)

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
