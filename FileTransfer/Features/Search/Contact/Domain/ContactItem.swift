import Foundation

struct ContactItem: Identifiable {
    let id = UUID()
    let displayName: String
    let phoneNumbers: [String]
    let emailAddresses: [String]
}
