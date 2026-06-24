import SwiftUI

struct RootView: View {
    @State private var coordinator = AppCoordinator()
    @Namespace private var hero

    var body: some View {
        ZStack {
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
