import Foundation

struct ContactInfo: Codable, Sendable, Hashable {
    let name: String
    let phone: String?
    let colorCode: ContactColor
    /// Downsized JPEG contact photo, if the contact has one. Falls back to
    /// initials-on-color-circle in the UI when nil.
    let photoData: Data?

    init(name: String, phone: String?, photoData: Data? = nil) {
        self.name = name
        self.phone = phone
        self.colorCode = .assigned(for: name)
        self.photoData = photoData
    }

    // Backward-compatible: old records without colorCode/photoData fall back
    // to the hash assignment / no photo.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name      = try c.decode(String.self, forKey: .name)
        phone     = try c.decodeIfPresent(String.self, forKey: .phone)
        colorCode = try c.decodeIfPresent(ContactColor.self, forKey: .colorCode) ?? .assigned(for: name)
        photoData = try c.decodeIfPresent(Data.self, forKey: .photoData)
    }

    nonisolated var initials: String {
        name.split(separator: " ").prefix(2)
            .compactMap(\.first).map(String.init).joined()
    }

    private enum CodingKeys: String, CodingKey {
        case name, phone, colorCode, photoData
    }
}
