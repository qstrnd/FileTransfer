import Foundation

/// Shared hex ⇄ string helpers for wire formats that must survive transports
/// which can't carry arbitrary UTF-8 (HTTP header values, MPC resource names).
///
/// The private copies inside `MediaTransferResource`/`FileTransferResource`
/// predate this file and are intentionally left untouched; new wire code
/// uses these.
nonisolated enum HexCoding {
    nonisolated static func encode(_ string: String) -> String {
        string.utf8.map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func decode(_ hex: String) -> String? {
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
}
