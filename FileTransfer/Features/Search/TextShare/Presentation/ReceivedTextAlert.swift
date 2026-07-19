import SwiftUI
import UIKit

/// Shown when a text message arrives from a peer. Uses the shared
/// `ReceivedTransferAlert` chrome (header, history-retention notice, button
/// style) so it matches the media / file / contact alerts, with a selectable
/// message body and Copy / Close actions.
struct ReceivedTextAlert: View {
    let message: TransferMessage?
    let onDismiss: () -> Void
    /// Called right after the text is copied to the pasteboard, before the card
    /// dismisses. The caller shows the "Copied to clipboard" toast in its own
    /// window so it isn't torn down along with this alert's window — see
    /// `CopiedToast` and its `PinnedWindow` in `SearchView`.
    let onCopied: () -> Void

    var body: some View {
        ReceivedTransferAlert(
            transfer: message,
            senderName: { $0.senderName },
            subtitle: { _ in "sent you a message" },
            content: { message in
                // UITextView-backed view for reliable text selection.
                // isScrollEnabled=false lets UITextView report true content height
                // so the card sizes dynamically. SwiftUI ScrollView handles overflow.
                ScrollView {
                    SelectableTextView(text: message.text)
                        .padding(.horizontal, 4)
                }
                .frame(maxHeight: 320)
            },
            actionRows: { message in
                [
                    [ReceivedAlertAction(title: "Copy") { copyAndDismiss(message.text) }],
                    [ReceivedAlertAction(title: "Close") { onDismiss() }],
                ]
            }
        )
    }

    // MARK: - Actions

    private func copyAndDismiss(_ text: String) {
        UIPasteboard.general.string = text
        onCopied()
        onDismiss()   // dismiss the card immediately
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
        // Non-scrolling so UITextView reports true intrinsic content size,
        // which lets SwiftUI size the card dynamically to the text height.
        tv.isScrollEnabled = false
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
        return CGSize(width: width, height: height)
    }
}

// MARK: - Previews

#Preview("Received") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        ReceivedTextAlert(
            message: TransferMessage(senderName: "🦒 Cunning Giraffe", text: "Hey, on my way! Should be there in about 10 minutes. See you soon 👋"),
            onDismiss: {},
            onCopied: {}
        )
    }
}

#Preview("Long text") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        ReceivedTextAlert(
            message: TransferMessage(senderName: "🐺 Puffy Wolf", text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur."),
            onDismiss: {},
            onCopied: {}
        )
    }
}

#Preview("Hidden") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        ReceivedTextAlert(message: nil, onDismiss: {}, onCopied: {})
    }
}
