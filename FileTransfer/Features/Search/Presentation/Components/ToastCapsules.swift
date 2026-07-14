import SwiftUI

// MARK: - Toast capsule content

/// Standard capsule shell shared by every toast: pinned to the top, glass
/// background, drop shadow. Toast content views wrap their inner view in this.
struct ToastCapsuleShell<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .glassEffect(in: Capsule())
            .shadow(color: .black.opacity(0.28), radius: 20, y: 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 6)
    }
}

struct PeerToastCapsule: View {
    let peer: Peer
    let message: String

    var body: some View {
        ToastCapsuleShell {
            HStack(spacing: 6) {
                Text(peer.emojiComponent)
                Text("\(peer.nameComponent) \(message)")
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}

struct TextToastCapsule: View {
    let text: String

    var body: some View {
        ToastCapsuleShell {
            Text(text)
                .font(.subheadline.weight(.semibold))
        }
    }
}

struct ReceivingToastCapsule: View {
    let progress: ReceivingProgress

    var body: some View {
        ToastCapsuleShell {
            VStack(spacing: 3) {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("\(progress.senderName) · \(progress.receivedCount) of \(progress.totalCount)")
                        .font(.subheadline.weight(.semibold))
                }
                // The receiver runs a foreground server without background
                // continuation — leaving the app cancels the reception.
                if !TransferFeatureFlags.backgroundTransferAndLiveActivity {
                    KeepAppOpenHint(compact: true)
                }
            }
        }
    }
}
