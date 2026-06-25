import Foundation
import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class AppCoordinator {
    private(set) var searchViewModel: SearchViewModel?

    private let service: any NearbySessionService
    private let identityStore: any DeviceIdentityStore
    private let connectionHistory: any ConnectionHistoryStore
    private let profileStore: any UserProfileStore
    private let historyStore: TransferHistoryStore

    /// The most recently saved profile, used to pre-fill the onboarding screen
    /// when the user navigates back from the search screen.
    var savedProfile: UserProfile? { profileStore.savedProfile }

    init(
        service: any NearbySessionService = MultipeerNearbyService(),
        identityStore: any DeviceIdentityStore = UserDefaultsDeviceIdentityStore(),
        connectionHistory: any ConnectionHistoryStore = UserDefaultsConnectionHistoryStore(),
        profileStore: any UserProfileStore = UserDefaultsUserProfileStore()
    ) {
        self.service = service
        self.identityStore = identityStore
        self.connectionHistory = connectionHistory
        self.profileStore = profileStore
        self.historyStore = Self.makeHistoryStore()
        // All stored properties are initialised — safe to reference self.
        // Skip onboarding if the user has already set up their profile.
        if let profile = profileStore.savedProfile {
            searchViewModel = makeSearchViewModel(emoji: profile.emoji, name: profile.name)
        }
    }

    private static func makeHistoryStore() -> TransferHistoryStore {
        do {
            let container = try ModelContainer(for: TransferItem.self)
            return TransferHistoryStore(context: ModelContext(container))
        } catch {
            // Fallback to in-memory if the on-disk container fails to open.
            let container = try! ModelContainer(
                for: TransferItem.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            return TransferHistoryStore(context: ModelContext(container))
        }
    }

    // MARK: - Navigation

    func proceedFromOnboarding(emoji: String, name: String) {
        profileStore.save(UserProfile(emoji: emoji, name: name))
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            searchViewModel = makeSearchViewModel(emoji: emoji, name: name)
        }
    }

    private func backToOnboarding() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            searchViewModel = nil
        }
    }

    // MARK: - Factory

    private func makeSearchViewModel(emoji: String, name: String) -> SearchViewModel {
        SearchViewModel(
            emoji: emoji,
            name: name,
            deviceID: identityStore.deviceID,
            service: service,
            connectionHistory: connectionHistory,
            historyStore: historyStore,
            onBack: { [weak self] in self?.backToOnboarding() }
        )
    }
}
