import Foundation

/// Port for persisting or sharing received media items.
/// All methods must be called on the MainActor.
@MainActor
protocol MediaSavingGate {
    func saveToGallery(_ items: [ReceivedMediaItem]) async -> Bool
    func saveToFiles(_ items: [ReceivedMediaItem])
    func share(_ items: [ReceivedMediaItem])
}
