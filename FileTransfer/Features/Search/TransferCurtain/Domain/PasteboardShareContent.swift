import Foundation

/// A classified, ready-to-share snapshot of the system pasteboard.
///
/// Produced by `PasteboardShareImporter` and confirmed by the user in
/// `PasteboardShareAlert` before anything is sent. Classification follows the
/// rule: images-only are shared as images, plain text as text, and anything
/// else (or a mix of unrelated data) as files. The associated URLs point at
/// temporary files written during import.
enum PasteboardShareContent: Identifiable, Equatable {
    case text(String)
    case images([URL])
    case files([PasteboardShareFile])

    var id: String {
        switch self {
        case .text(let value):   "text:\(value.hashValue)"
        case .images(let urls):  "images:" + urls.map(\.lastPathComponent).joined(separator: ",")
        case .files(let files):  "files:" + files.map(\.id.uuidString).joined(separator: ",")
        }
    }

    /// Temp file URLs backing this content, so they can be cleaned up on cancel.
    var temporaryURLs: [URL] {
        switch self {
        case .text:              []
        case .images(let urls):  urls
        case .files(let files):  files.map(\.url)
        }
    }
}

/// A single file pulled from the pasteboard, with a display name and an SF
/// Symbol representing its kind for the confirmation preview.
struct PasteboardShareFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let name: String
    let systemImage: String
}
