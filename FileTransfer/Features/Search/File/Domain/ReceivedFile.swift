import Foundation

struct ReceivedFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
}
