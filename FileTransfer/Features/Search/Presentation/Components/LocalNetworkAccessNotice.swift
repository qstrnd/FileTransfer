import SwiftUI
import UIKit

/// Static (non-animated) replacement for `SearchingText`, shown when the
/// self-discovery probe can't confirm local network access. The probe only
/// checks the Bonjour/Wi-Fi path (see `LocalNetworkAccessChecker`) — it can't
/// tell apart Local Network permission being off, Wi-Fi being off, or
/// Bluetooth being off, since Multipeer can also connect over Bluetooth. The
/// copy stays deliberately non-specific about which one it is; it's only
/// shown once MPC itself has found zero peers too.
struct LocalNetworkAccessNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Can't reach\nother devices")
                .font(.system(size: 30, weight: .bold))
                .multilineTextAlignment(.leading)
                .foregroundStyle(.secondary)

            Text("Turn on **Local Network** for FileTransfer in Settings, and check that Wi-Fi, Cellular or Bluetooth is on.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape")
                    Text("Open FileTransfer in Settings")
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Previews

#Preview {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        VStack {
            Spacer()
            LocalNetworkAccessNotice()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
            Spacer()
            Spacer()
        }
    }
}
