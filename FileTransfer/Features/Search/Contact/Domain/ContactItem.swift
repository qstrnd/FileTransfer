import Foundation

struct ContactItem: Identifiable {
    let id = UUID()
    let displayName: String
    let phoneNumbers: [String]
    let emailAddresses: [String]
    /// Downsized JPEG contact photo, if the contact has one. Falls back to
    /// initials-on-color-circle in the UI when nil.
    let photoData: Data?

    init(
        displayName: String,
        phoneNumbers: [String],
        emailAddresses: [String],
        photoData: Data? = nil
    ) {
        self.displayName = displayName
        self.phoneNumbers = phoneNumbers
        self.emailAddresses = emailAddresses
        self.photoData = photoData
    }
}
