import Foundation

struct ContactInfo: Codable, Sendable, Hashable {
    let name: String
    let phone: String?
    let colorCode: ContactColor

    init(name: String, phone: String?) {
        self.name = name
        self.phone = phone
        self.colorCode = .assigned(for: name)
    }

    // Backward-compatible: old records without colorCode fall back to the hash assignment.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name      = try c.decode(String.self, forKey: .name)
        phone     = try c.decodeIfPresent(String.self, forKey: .phone)
        colorCode = try c.decodeIfPresent(ContactColor.self, forKey: .colorCode) ?? .assigned(for: name)
    }

    nonisolated var initials: String {
        name.split(separator: " ").prefix(2)
            .compactMap(\.first).map(String.init).joined()
    }

    private enum CodingKeys: String, CodingKey {
        case name, phone, colorCode
    }
}
