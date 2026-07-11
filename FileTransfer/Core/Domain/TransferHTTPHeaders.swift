import Foundation

/// Encodes/decodes the custom `X-FT-*` headers that carry transfer-item
/// metadata over the HTTP data plane. Pure and symmetric: whatever `encode`
/// produces, `decode` reconstructs (and vice versa), which the unit tests
/// verify both ways.
///
/// Filenames and display names are hex-encoded UTF-8 because HTTP header
/// values can't safely carry arbitrary Unicode (peer names contain emoji).
nonisolated enum TransferHTTPHeaders {
    nonisolated static let transferID    = "X-FT-Transfer-ID"
    nonisolated static let payload       = "X-FT-Payload"
    nonisolated static let index         = "X-FT-Index"
    nonisolated static let total         = "X-FT-Total"
    nonisolated static let kind          = "X-FT-Kind"
    nonisolated static let ext           = "X-FT-Ext"
    nonisolated static let nameHex       = "X-FT-Name-Hex"
    nonisolated static let sha256        = "X-FT-SHA256"
    nonisolated static let senderID      = "X-FT-Sender-ID"
    nonisolated static let senderNameHex = "X-FT-Sender-Name-Hex"

    struct Sender: Sendable, Equatable {
        let deviceID: UUID
        let displayName: String
    }

    // MARK: - Encode

    nonisolated static func encode(
        item: IncomingTransferItemInfo, sender: Sender, sha256Hex: String
    ) -> [String: String] {
        var headers: [String: String] = [
            transferID:    item.transferID,
            payload:       item.payload.rawValue,
            index:         String(item.index),
            total:         String(item.total),
            ext:           item.fileExtension,
            sha256:        sha256Hex,
            senderID:      sender.deviceID.uuidString,
            senderNameHex: HexCoding.encode(sender.displayName),
        ]
        if item.kind != .regular { headers[kind] = item.kind.rawValue }
        if let name = item.fileName { headers[nameHex] = HexCoding.encode(name) }
        return headers
    }

    // MARK: - Decode

    /// Returns nil when any required header is missing or malformed.
    /// Header lookup is case-insensitive per RFC 9110.
    nonisolated static func decode(
        _ rawHeaders: [String: String]
    ) -> (item: IncomingTransferItemInfo, sender: Sender, sha256Hex: String)? {
        let headers = Dictionary(
            rawHeaders.map { ($0.key.lowercased(), $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        func value(_ name: String) -> String? { headers[name.lowercased()] }

        guard
            let id = value(transferID), !id.isEmpty,
            let payloadRaw = value(payload),
            let payloadKind = IncomingTransferItemInfo.Payload(rawValue: payloadRaw),
            let idx = value(index).flatMap(Int.init), idx >= 0,
            let ttl = value(total).flatMap(Int.init), ttl > 0,
            let fileExt = value(ext), !fileExt.isEmpty,
            let digest = value(sha256), digest.count == 64,
            let senderUUID = value(senderID).flatMap(UUID.init(uuidString:)),
            let senderName = value(senderNameHex).flatMap(HexCoding.decode), !senderName.isEmpty
        else { return nil }

        let mediaKind = value(kind).flatMap(MediaFileKind.init(rawValue:)) ?? .regular
        let name = value(nameHex).flatMap(HexCoding.decode)
        // Files must carry their original name; media names are optional.
        if payloadKind == .file && name == nil { return nil }

        let item = IncomingTransferItemInfo(
            transferID: id, index: idx, total: ttl,
            payload: payloadKind, kind: mediaKind,
            fileName: name, fileExtension: fileExt.lowercased()
        )
        return (item, Sender(deviceID: senderUUID, displayName: senderName), digest.lowercased())
    }
}
