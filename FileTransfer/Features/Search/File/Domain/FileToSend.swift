import Foundation

struct FileToSend: Sendable {
    let url: URL
    let name: String
    let index: Int
    let total: Int
}
