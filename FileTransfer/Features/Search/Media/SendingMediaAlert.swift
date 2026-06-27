import SwiftUI

struct SendingMediaAlert: View {
    let transfer: OutgoingMediaTransfer?
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

    private func card(for transfer: OutgoingMediaTransfer) -> some View {
        VStack(spacing: 0) {
            if transfer.isComplete {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 52))
                    Text("Sent!")
                        .font(.title2.weight(.semibold))
                }
                .padding(.vertical, 40)
                .padding(.horizontal, 24)
            } else {
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
        .glassEffect(in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .animation(.spring(duration: 0.35), value: transfer.isComplete)
        .padding(.horizontal, 40)
    }
}
