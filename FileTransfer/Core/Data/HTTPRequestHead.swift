import Foundation

/// Minimal HTTP/1.1 request head: request line + headers, parsed from the
/// bytes up to (and excluding) the `\r\n\r\n` terminator. Pure value type so
/// the parser is unit-testable without any networking.
///
/// Deliberately supports only what the transfer wire protocol needs — a
/// single request per connection, no chunked encoding, no continuation lines.
nonisolated struct HTTPRequestHead: Sendable, Equatable {
    let method: String
    let path: String
    /// Keys lowercased; last occurrence wins for duplicates.
    let headers: [String: String]

    var contentLength: Int64? {
        headers["content-length"].flatMap(Int64.init).flatMap { $0 >= 0 ? $0 : nil }
    }

    /// Parses a complete head (bytes before the blank line). Returns nil for
    /// anything malformed: bad request line, non-HTTP version, garbage header.
    nonisolated init?(parsing data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        // Tolerate bare-\n clients; the wire protocol always sends \r\n.
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
        guard let requestLine = lines.first, !requestLine.isEmpty else { return nil }

        let parts = requestLine.components(separatedBy: " ")
        guard parts.count == 3,
              !parts[0].isEmpty, !parts[1].isEmpty,
              parts[2].hasPrefix("HTTP/1.")
        else { return nil }
        method = parts[0].uppercased()
        path = parts[1]

        var parsed: [String: String] = [:]
        for line in lines.dropFirst() where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { return nil }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return nil }
            parsed[name.lowercased()] = value
        }
        headers = parsed
    }

    /// Locates the end of the head (`\r\n\r\n`) in a growing receive buffer.
    /// Returns the range of the terminator so callers can split head from body.
    nonisolated static func headTerminatorRange(in buffer: Data) -> Range<Data.Index>? {
        buffer.firstRange(of: Data("\r\n\r\n".utf8))
    }
}
