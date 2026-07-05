import SwiftUI

/// "Copied to clipboard" confirmation shown after the Copy action in
/// `ReceivedTextAlert`. Triggered via `ToastCenter.shared.show { CopiedToast() }`
/// so it's presented independently of the alert's own window/lifecycle.
struct CopiedToast: View {
    var body: some View {
        ToastCapsuleShell {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 17, weight: .semibold))
                Text("Copied to clipboard")
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}

#Preview("Copied toast") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        CopiedToast()
    }
}
