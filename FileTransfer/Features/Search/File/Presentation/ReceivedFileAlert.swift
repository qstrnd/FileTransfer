import SwiftUI

struct ReceivedFileAlert: View {
    let transfer: ReceivedFileTransfer?
    let thumbnailGate: any HistoryThumbnailGate
    let onDismiss: () -> Void
    let onDeleteRecord: (UUID) -> Void
    let onSaveToFiles: ([ReceivedFile]) -> Void
    let onShare: ([ReceivedFile]) -> Void

    var body: some View {
        ReceivedTransferAlert(
            transfer: transfer,
            senderName: { $0.senderName },
            subtitle: { $0.files.count == 1 ? "sent you a file" : "sent you \($0.files.count) files" },
            recordID: { $0.recordID },
            onDeleteRecord: onDeleteRecord,
            content: { transfer in
                FilePreviewStrip(files: transfer.files, gate: thumbnailGate)
                    .frame(height: FilePreviewStrip.height(for: transfer.files.count))
            },
            actions: { transfer in
                [
                    ReceivedAlertAction(title: "Save to Files", systemImage: "folder") {
                        onSaveToFiles(transfer.files)
                        onDismiss()
                    },
                    ReceivedAlertAction(title: "Share", systemImage: "square.and.arrow.up") {
                        onShare(transfer.files)
                        onDismiss()
                    },
                    ReceivedAlertAction(title: "Close", systemImage: "xmark", isSecondary: true) {
                        onDismiss()
                    },
                ]
            }
        )
    }
}
