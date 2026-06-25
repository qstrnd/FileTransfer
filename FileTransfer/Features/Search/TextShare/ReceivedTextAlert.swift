import SwiftUI
import UIKit

/// Full-screen overlay shown when a text message arrives from a peer.
/// Follows the same always-in-hierarchy pattern as InvitationAlert so
/// backdrop, card, and toast can animate independently.
struct ReceivedTextAlert: View {
    let message: TransferMessage?
    let onDismiss: () -> Void

    @State private var showCopiedToast = false

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
            if showCopiedToast {
                copiedToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 12)
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(duration: 0.3), value: message?.id)
        .animation(.spring(duration: 0.35), value: showCopiedToast)
        .onChange(of: message?.id) { _, _ in showCopiedToast = false }
    }

    // MARK: - Card

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

            // UITextView-backed view: supports simultaneous selection + scroll
            // without SwiftUI gesture conflicts that block .textSelection(.enabled)
            SelectableTextView(text: message.text)
                .frame(maxHeight: 260)
                .padding(.horizontal, 4)

            Divider()

            // Action row
            HStack(spacing: 0) {
                Button {
                    copyAndDismiss(message.text)
                } label: {
                    Text("Copy")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }

                Divider()
                    .frame(height: 52)

                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .padding(.horizontal, 24)
    }

    // MARK: - Toast

    private var copiedToast: some View {
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
    }

    // MARK: - Actions

    private func copyAndDismiss(_ text: String) {
        UIPasteboard.general.string = text
        showCopiedToast = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            onDismiss()
        }
    }
}

// MARK: - Selectable text view

/// UITextView wrapper that gives reliable text selection inside a constrained
/// height container. SwiftUI's Text + .textSelection(.enabled) conflicts with
/// ScrollView's pan gesture recognizer, making selection unreliable.
private struct SelectableTextView: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isScrollEnabled = true
        tv.backgroundColor = .clear
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.adjustsFontForContentSizeCategory = true
        tv.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        tv.textContainer.lineFragmentPadding = 0
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 300
        let height = uiView.sizeThatFits(CGSize(width: width, height: .infinity)).height
        return CGSize(width: width, height: min(height, 260))
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

#Preview("Long text") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        ReceivedTextAlert(
            message: TransferMessage(senderName: "🐺 Puffy Wolf", text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur."),
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
