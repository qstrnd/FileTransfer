import SwiftUI

/// The ⋯ overflow button at the top of SearchView: a shortcut to edit the
/// profile plus the transfer-history retention picker.
///
/// The toggle-able settings live in `SettingsMenuViewModel`; the profile
/// shortcut is a plain navigation callback owned by the screen.
struct SettingsMenu: View {
    @Bindable var viewModel: SettingsMenuViewModel
    var onUpdateProfile: () -> Void

    var body: some View {
        Menu {
            Button("Update Profile") { onUpdateProfile() }
            Toggle("Auto-connect On Startup", isOn: $viewModel.autoConnectOnStartup)
            Section("Keep Transfer History") {
                ForEach(HistoryRetention.allCases) { retention in
                    Button {
                        viewModel.historyRetention = retention
                    } label: {
                        if viewModel.historyRetention == retention {
                            Label(retention.title, systemImage: "checkmark")
                        } else {
                            Text(retention.title)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 30, height: 30)
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .padding(.top, 8)
        .padding(.trailing, 20)
    }
}
