import SwiftUI

struct RootView: View {
    @State private var coordinator = AppCoordinator()
    @Namespace private var hero

    var body: some View {
        ZStack {
            // if/else lets SwiftUI know exactly which view is entering and which
            // is leaving, giving matchedGeometryEffect a stable source/destination
            // pair and eliminating the "jump back first" artefact.
            if let vm = coordinator.searchViewModel {
                SearchView(viewModel: vm, namespace: hero)
                    .transition(.opacity)
                    .zIndex(1)
            } else {
                OnboardingView(onProceed: coordinator.proceedFromOnboarding, namespace: hero)
                    .transition(.opacity)
                    .zIndex(0)
            }
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.85),
                   value: coordinator.searchViewModel == nil)
    }
}

#Preview {
    RootView()
}
