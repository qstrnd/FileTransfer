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
}

extension OutgoingMediaTransfer {
    var sendingStatus: SendingTransferStatus {
        SendingTransferStatus(id: id, totalItems: totalItems, peerCount: peerCount, isComplete: isComplete)
    }
}

extension OutgoingContactTransfer {
    var sendingStatus: SendingTransferStatus {
        SendingTransferStatus(id: id, totalItems: totalItems, peerCount: peerCount, isComplete: isComplete)
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
            ZStack {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.4)
                        .padding(.bottom, 4)
                    Text("Sending \(transfer.totalItems) item\(transfer.totalItems == 1 ? "" : "s")")
                        .font(.title3.weight(.semibold))
                    Text("to \(transfer.peerCount) device\(transfer.peerCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .opacity(transfer.isComplete ? 0 : 1)

                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 52))
                    Text("Sent!")
                        .font(.title2.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .opacity(transfer.isComplete ? 1 : 0)
            }
            .padding(.top, 32)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            Divider()
                .opacity(transfer.isComplete ? 0 : 1)

            Button(role: .destructive, action: onAbort) {
                Text("Cancel")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .opacity(transfer.isComplete ? 0 : 1)
            .disabled(transfer.isComplete)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .animation(.spring(duration: 0.35), value: transfer.isComplete)
        .padding(.horizontal, 40)
    }
}
