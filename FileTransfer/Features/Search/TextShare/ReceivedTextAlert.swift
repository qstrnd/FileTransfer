import SwiftUI

/// Full-screen overlay shown when a text message arrives from a peer.
/// Follows the same always-in-hierarchy pattern as InvitationAlert so
/// backdrop and card can animate in/out independently.
struct ReceivedTextAlert: View {
    let message: TransferMessage?
    let onDismiss: () -> Void

    private let cardCornerRadius: CGFloat = 20

    var body: some View {
        ZStack {
            if message != nil {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
                    .transition(.opacity)
            }
            if let message {
                alertCard(for: message)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(duration: 0.3), value: message?.id)
    }

    private func alertCard(for message: TransferMessage) -> some View {
        let emoji = String(message.senderName.prefix(1))
        let name: String = {
            guard let idx = message.senderName.firstIndex(of: " ") else { return message.senderName }
            return String(message.senderName[message.senderName.index(after: idx)...])
        }()

        return VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 44))
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("sent you a message")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Divider()

            // Selectable message body
            ScrollView {
                Text(message.text)
                    .textSelection(.enabled)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .frame(maxHeight: 260)

            Divider()

            Button(action: onDismiss) {
                Text("Dismiss")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .padding(.horizontal, 24)
    }
}

// MARK: - Previews

#Preview("Received") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        ReceivedTextAlert(
            message: TransferMessage(senderName: "🦒 Cunning Giraffe", text: "Hey, on my way! Should be there in about 10 minutes. See you soon 👋"),
            onDismiss: {}
        )
    }
}

#Preview("Hidden") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        ReceivedTextAlert(message: nil, onDismiss: {})
    }
}
