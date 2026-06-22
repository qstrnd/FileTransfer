import SwiftUI

struct RootView: View {
    @State private var coordinator = AppCoordinator()

    var body: some View {
        if let vm = coordinator.transferViewModel {
            TransferView(viewModel: vm)
        } else {
            SetupView(onStart: coordinator.start)
        }
    }
}

#Preview {
    RootView()
}
