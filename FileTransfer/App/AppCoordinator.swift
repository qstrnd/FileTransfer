import Foundation
import Observation

@MainActor
@Observable
final class AppCoordinator {
    private(set) var showMain = false

    private let service: any NearbySessionService

    init(service: any NearbySessionService = MultipeerNearbyService()) {
        self.service = service
    }

    func proceedFromOnboarding(emoji: String, name: String) {
        showMain = true
    }
}
