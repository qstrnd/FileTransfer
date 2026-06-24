import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppCoordinator {
    private(set) var searchViewModel: SearchViewModel?

    private let service: any NearbySessionService
    private let identityStore: any DeviceIdentityStore
    private let connectionHistory: any ConnectionHistoryStore

    init(
        service: any NearbySessionService = MultipeerNearbyService(),
        identityStore: any DeviceIdentityStore = UserDefaultsDeviceIdentityStore(),
        connectionHistory: any ConnectionHistoryStore = UserDefaultsConnectionHistoryStore()
    ) {
        self.service = service
        self.identityStore = identityStore
        self.connectionHistory = connectionHistory
    }

    func proceedFromOnboarding(emoji: String, name: String) {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            searchViewModel = SearchViewModel(
                emoji: emoji,
                name: name,
                deviceID: identityStore.deviceID,
                service: service,
                connectionHistory: connectionHistory,
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
