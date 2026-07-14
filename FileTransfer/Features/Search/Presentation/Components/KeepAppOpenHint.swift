import SwiftUI

/// Reminder shown while a transfer is in flight when background continuation is
/// disabled (`TransferFeatureFlags.backgroundTransferAndLiveActivity`). Without
/// it the transfer only proceeds while the app is foreground, so both the
/// sender and the receiver must keep the app open until it finishes.
struct KeepAppOpenHint: View {
    /// Renders a single tight line for the receiving toast capsule.
    var compact = false

    var body: some View {
        Label(
            compact ? "Keep the app open" : "Keep the app open until it's done",
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(compact ? .caption2.weight(.medium) : .footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
}
