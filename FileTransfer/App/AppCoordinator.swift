import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppCoordinator {
    private(set) var searchViewModel: SearchViewModel?

    private let service: any NearbySessionService

    init(service: any NearbySessionService = MultipeerNearbyService()) {
        self.service = service
    }

    func proceedFromOnboarding(emoji: String, name: String) {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            searchViewModel = SearchViewModel(
                emoji: emoji,
                name: name,
                service: service,
                onBack: { [weak self] in self?.backToOnboarding() }
            )
        }
    }

    private func backToOnboarding() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            searchViewModel = nil
        }
    }
}
