import SwiftUI

struct RootView: View {
    @State private var coordinator = AppCoordinator()
    @Namespace private var hero

    var body: some View {
        ZStack {
            // Two separate `if` blocks (not if/else) keep both views in the tree
            // simultaneously during the transition so matchedGeometryEffect can
            // animate the hero circle between its onboarding and search positions.
            if coordinator.searchViewModel == nil {
                OnboardingView(onProceed: coordinator.proceedFromOnboarding, namespace: hero)
                    .transition(.opacity)
                    .zIndex(0)
            }
            if let vm = coordinator.searchViewModel {
                SearchView(viewModel: vm, namespace: hero)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
    }
}

#Preview {
    RootView()
}
