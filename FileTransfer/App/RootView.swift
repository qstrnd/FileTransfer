import SwiftUI

struct RootView: View {
    @State private var coordinator = AppCoordinator()

    var body: some View {
        if coordinator.showMain {
            MainView()
        } else {
            OnboardingView(onProceed: coordinator.proceedFromOnboarding)
        }
    }
}

#Preview {
    RootView()
}
