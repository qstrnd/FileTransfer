import Foundation

struct ContactInfo: Codable, Sendable, Hashable {
    let name: String
    let phone: String?

    nonisolated var initials: String {
        name.split(separator: " ").prefix(2)
            .compactMap(\.first).map(String.init).joined()
    }
}
