import SwiftUI
import UIKit

/// "Copied to clipboard" confirmation shown after the Copy action in
/// `ReceivedTextAlert`. Hosted in its own `PinnedWindow` (see `SearchView`) at a
/// window level above the alert's, so it survives — and stays visible above —
/// the alert card's dismissal instead of being torn down along with it.
struct CopiedToast: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 17, weight: .semibold))
            Text("Copied to clipboard")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 12)
    }
}

#Preview("Copied toast") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        CopiedToast()
    }
}
