import SwiftUI

struct SetupView: View {
    @State private var viewModel: SetupViewModel

    init(onStart: @escaping (String) -> Void) {
        _viewModel = State(initialValue: SetupViewModel(onStart: onStart))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Identity") {
                    HStack(spacing: 12) {
                        TextField("🙂", text: $viewModel.emoji)
                            .frame(width: 44)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                        TextField("Display name", text: $viewModel.name)
                    }
                }
                Section {
                    Button("Start Advertising") {
                        viewModel.start()
                    }
                    .disabled(!viewModel.canStart)
                } footer: {
                    Text("Other instances of this app on the same network will discover you.")
                }
            }
            .navigationTitle("FileTransfer")
        }
    }
}

#Preview {
    SetupView(onStart: { _ in })
}
