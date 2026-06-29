import SwiftUI

/// Connection-request alert with filled Accept (blue) and Decline (red) buttons.
///
/// Takes an optional peer so it can live permanently in the overlay and give
/// each layer its own transition:
/// - Backdrop: opacity only — no scale
/// - Card: opacity + scale — matches native alert feel
///
/// Liquid Glass (iOS 26) is applied to the card background via glassEffect(in:).
/// System foreground styles (.primary / .secondary) produce the vibrancy
/// treatment that HIG recommends for text on glass surfaces.
struct InvitationAlert: View {
    /// Pass nil to hide the alert; the view stays in the hierarchy so transitions work.
    let peer: Peer?
    let onAccept: () -> Void
    let onDecline: () -> Void

    // Matches the squircle radius visible in Apple's Liquid Glass alert guidelines.
    private let cardCornerRadius: CGFloat = 20

    var body: some View {
        ZStack {
            // ── Backdrop ──────────────────────────────────────────────────────
            // Fades only — no scale. allowsHitTesting(true) ensures it blocks
            // interaction with content behind without triggering any action.
            if peer != nil {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
                    .transition(.opacity)
            }

            // ── Card ──────────────────────────────────────────────────────────
            // Scales + fades independently of the backdrop.
            if let peer {
                alertCard(peer: peer)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        // Drives both transitions from a single value change.
        .animation(.spring(duration: 0.3), value: peer?.id)
    }

    // MARK: - Card

    private func alertCard(peer: Peer) -> some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Text(peer.emojiComponent)
                    .font(.system(size: 48))
                Text("Connection Request")
                    .font(.headline)
                    // .primary on glass gets automatic vibrancy (HIG).
                    .foregroundStyle(.primary)
                Text("\(peer.nameComponent) wants to connect")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            Divider()

            // Buttons — capsule shape matches Apple's reference corner radius.
            HStack(spacing: 12) {
                Button(action: onDecline) {
                    Text("Decline")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red, in: Capsule())
                }

                Button(action: onAccept) {
                    Text("Accept")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor, in: Capsule())
                }
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        // Liquid Glass card background (iOS 26). glassEffect clips to the shape
        // and composites the underlying content through the glass material.
        .glassEffect(in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .frame(maxWidth: 400)
        .padding(.horizontal, 36)
    }
}

// MARK: - Preview

#Preview("With peer") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        InvitationAlert(
            peer: Peer(displayName: "🦙 Happy Llama"),
            onAccept: {},
            onDecline: {}
        )
    }
}

#Preview("Hidden") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        InvitationAlert(peer: nil, onAccept: {}, onDecline: {})
    }
}
