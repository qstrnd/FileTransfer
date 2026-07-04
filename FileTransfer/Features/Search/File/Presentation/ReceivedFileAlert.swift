import SwiftUI

struct ReceivedFileAlert: View {
    let transfer: ReceivedFileTransfer?
    let thumbnailGate: any HistoryThumbnailGate
    let onDismiss: () -> Void
    let onSaveToFiles: ([ReceivedFile]) -> Void
    let onShare: ([ReceivedFile]) -> Void

    private let cardCornerRadius: CGFloat = 20

    var body: some View {
        ZStack {
            if transfer != nil {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
                    .transition(.opacity)
            }
            if let transfer {
                alertCard(for: transfer)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(duration: 0.3), value: transfer?.id)
    }

    private func alertCard(for transfer: ReceivedFileTransfer) -> some View {
        let (emoji, name) = Peer.parseDisplayName(transfer.senderName)
        let count = transfer.files.count
        let subtitle = count == 1 ? "sent you a file" : "sent you \(count) files"

        return VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 44))
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Divider()

            FilePreviewStrip(files: transfer.files, gate: thumbnailGate)
                .frame(height: FilePreviewStrip.height(for: transfer.files.count))

            Divider()

            VStack(spacing: 0) {
                Button {
                    onSaveToFiles(transfer.files)
                    onDismiss()
                } label: {
                    Text("Save to Files")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }

                Divider()

                Button {
                    onShare(transfer.files)
                    onDismiss()
                } label: {
                    Text("Share\u{2026}")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }

                Divider()

                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .frame(maxWidth: 400)
        .padding(.horizontal, 24)
    }
}
