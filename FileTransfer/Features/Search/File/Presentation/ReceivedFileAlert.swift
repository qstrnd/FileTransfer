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
            actionRows: { transfer in
                [
                    [
                        ReceivedAlertAction(title: "Save to Files") {
                            onSaveToFiles(transfer.files)
                            onDismiss()
                        },
                    ],
                    [
                        ReceivedAlertAction(title: "Share") {
                            onShare(transfer.files)
                            onDismiss()
                        },
                    ],
                    [
                        ReceivedAlertAction(title: "Close", isSecondary: true) {
                            onDismiss()
                        },
                    ],
                ]
            }
        )
    }
}
