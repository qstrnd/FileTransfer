import Foundation
import Observation

@Observable
final class SearchViewModel {
    let emoji: String
    let name: String

    private let service: any NearbySessionService
    private let onBack: () -> Void

    init(emoji: String, name: String, service: any NearbySessionService, onBack: @escaping () -> Void) {
        self.emoji = emoji
        self.name = name
        self.service = service
        self.onBack = onBack
    }

    func start() {
        service.start(displayName: "\(emoji) \(name)")
    }

    func stop() {
        service.stop()
    }

    func goBack() {
        service.stop()
        onBack()
    }
}
