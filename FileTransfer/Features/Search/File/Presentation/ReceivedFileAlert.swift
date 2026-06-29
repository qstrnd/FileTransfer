import SwiftUI

struct ReceivedFileAlert: View {
    let transfer: ReceivedFileTransfer?
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

            fileList(for: transfer.files)

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

    @ViewBuilder
    private func fileList(for files: [ReceivedFile]) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(files.enumerated()), id: \.element.id) { idx, file in
                    HStack(spacing: 12) {
                        Image(systemName: fileIcon(for: file.name))
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                            .frame(width: 32)
                        Text(file.name)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    if idx < files.count - 1 {
                        Divider().padding(.leading, 64)
                    }
                }
            }
        }
        .frame(maxHeight: 240)
    }

    private func fileIcon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "doc.richtext"
        case "doc", "docx", "txt", "rtf":
            return "doc.text"
        case "xls", "xlsx", "csv":
            return "tablecells"
        case "ppt", "pptx":
            return "rectangle.on.rectangle"
        case "zip", "gz", "tar", "rar", "7z":
            return "doc.zipper"
        case "mp3", "wav", "aac", "flac", "m4a":
            return "music.note"
        case "mp4", "mov", "avi", "mkv", "m4v":
            return "video"
        case "jpg", "jpeg", "png", "heic", "gif", "webp":
            return "photo"
        case "swift", "py", "js", "ts", "html", "css", "json", "xml":
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "doc"
        }
    }
}
