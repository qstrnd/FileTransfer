import Foundation
import Observation

@MainActor
@Observable
final class AppCoordinator {
    private(set) var transferViewModel: TransferViewModel?

    private let service: any NearbySessionService

    init(service: any NearbySessionService = MultipeerNearbyService()) {
        self.service = service
    }

    func start(displayName: String) {
        service.start(displayName: displayName)
        transferViewModel = TransferViewModel(service: service, onStop: { [weak self] in
            self?.transferViewModel = nil
        })
    }
}
