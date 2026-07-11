import SwiftUI

/// Concrete state snapshot used by SendingTransferAlert.
/// Both OutgoingMediaTransfer and OutgoingContactTransfer map to this type,
/// avoiding protocol-based generic constraints that conflict with
/// the module-wide @MainActor default actor isolation.
struct SendingTransferStatus: Identifiable {
    let id: UUID
    let totalItems: Int
    let peerCount: Int
    let isComplete: Bool
    /// Byte-level progress 0–1. For contact transfers this is binary (0 or 1).
    let progress: Double
    /// Item-sends that terminally failed (all transports/retries exhausted).
    var failedItems: Int = 0
}

extension OutgoingMediaTransfer {
    var sendingStatus: SendingTransferStatus {
        SendingTransferStatus(id: id, totalItems: totalItems, peerCount: peerCount,
                              isComplete: isComplete, progress: progress, failedItems: failures)
    }
}

extension OutgoingContactTransfer {
    var sendingStatus: SendingTransferStatus {
        SendingTransferStatus(id: id, totalItems: totalItems, peerCount: peerCount,
                              isComplete: isComplete, progress: isComplete ? 1 : 0)
    }
}

extension OutgoingFileTransfer {
    var sendingStatus: SendingTransferStatus {
        SendingTransferStatus(id: id, totalItems: totalFiles, peerCount: peerCount,
                              isComplete: isComplete, progress: progress, failedItems: failures)
    }
}

struct SendingTransferAlert: View {
    let transfer: SendingTransferStatus?
    let onAbort: () -> Void

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
                card(for: transfer)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(duration: 0.3), value: transfer?.id)
    }

    private func card(for transfer: SendingTransferStatus) -> some View {
        VStack(spacing: 0) {
            if transfer.isComplete {
                if transfer.failedItems > 0 {
                    failedContent(failedItems: transfer.failedItems)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                } else {
                    completeContent
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            } else {
                sendingContent(for: transfer)
                    .transition(.opacity)
            }
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .animation(.spring(response: 0.45, dampingFraction: 0.68), value: transfer.isComplete)
        .frame(maxWidth: 400)
        .padding(.horizontal, 40)
    }

    // MARK: - Sending state

    private func sendingContent(for transfer: SendingTransferStatus) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("Sending \(transfer.totalItems) item\(transfer.totalItems == 1 ? "" : "s")")
                    .font(.title3.weight(.semibold))
                Text("to \(transfer.peerCount) device\(transfer.peerCount == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressView(value: transfer.progress)
                    .tint(.blue)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 32)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            Divider()

            Button(role: .destructive, action: onAbort) {
                Text("Cancel")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
    }

    // MARK: - Complete state

    /// Vertically centered within the card — no divider/button below it, so
    /// the card shrinks to fit and the checkmark+"Sent!" pair sits dead-center.
    private var completeContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 64))
            Text("Sent!")
                .font(.title2.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 24)
    }

    // MARK: - Failed state

    private func failedContent(failedItems: Int) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 64))
            Text("Failed to send \(failedItems) item\(failedItems == 1 ? "" : "s")")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 24)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Sending — in progress") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        SendingTransferAlert(
            transfer: SendingTransferStatus(id: UUID(), totalItems: 5, peerCount: 2, isComplete: false, progress: 0.42),
            onAbort: {}
        )
    }
}

#Preview("Sending — complete") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        SendingTransferAlert(
            transfer: SendingTransferStatus(id: UUID(), totalItems: 5, peerCount: 2, isComplete: true, progress: 1),
            onAbort: {}
        )
    }
}

#Preview("Sending — failed") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        SendingTransferAlert(
            transfer: SendingTransferStatus(id: UUID(), totalItems: 5, peerCount: 2, isComplete: true, progress: 0.6, failedItems: 2),
            onAbort: {}
        )
    }
}

/// Loops sending → complete → sending so the pop-in transition for the
/// "Sent!" state can be watched repeatedly in the canvas.
#Preview("Sending → Sent (animated)") {
    SendingTransferAlertAnimationPreview()
}

private struct SendingTransferAlertAnimationPreview: View {
    @State private var isComplete = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            SendingTransferAlert(
                transfer: SendingTransferStatus(
                    id: UUID(), totalItems: 5, peerCount: 2,
                    isComplete: isComplete, progress: isComplete ? 1 : 0.65
                ),
                onAbort: {}
            )
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation { isComplete = true }
                try? await Task.sleep(for: .seconds(2))
                withAnimation { isComplete = false }
            }
        }
    }
}
#endif
