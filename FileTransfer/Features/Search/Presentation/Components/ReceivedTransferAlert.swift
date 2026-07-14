import SwiftUI

/// One button in a received-transfer alert's action list.
struct ReceivedAlertAction: Identifiable {
    let id = UUID()
    let title: String
    /// Rendered in a muted style (used for the neutral "Close" action).
    var isSecondary = false
    let action: () -> Void
}

/// Shared chrome for the "you received X" alerts (media / file / contact).
///
/// Owns the modal scrim, glass card, sender header, the persisted
/// "Keep in Transfer History" toggle, and the action-button list, so the three
/// received-transfer alerts stay visually and behaviourally unified. Each
/// specific alert supplies only its subtitle, preview content, and actions.
///
/// The toggle is persisted across sessions via `@AppStorage`. The history
/// record for the transfer is always created on receipt; when the alert is
/// dismissed with the toggle off, that record is removed via `onDeleteRecord`.
struct ReceivedTransferAlert<Transfer: Identifiable, Content: View>: View {
    /// Nil hides the alert; the view stays in the hierarchy so transitions play.
    let transfer: Transfer?
    let senderName: (Transfer) -> String
    let subtitle: (Transfer) -> String
    /// The history record id for this transfer, if any.
    let recordID: (Transfer) -> UUID?
    let onDeleteRecord: (UUID) -> Void
    @ViewBuilder let content: (Transfer) -> Content
    /// Action buttons grouped into rows; each row lays its buttons out as
    /// equal-width capsules side by side (e.g. `[[Save to Gallery, Save to
    /// Files], [Share], [Close]]`).
    let actionRows: (Transfer) -> [[ReceivedAlertAction]]

    @AppStorage("ft.keepReceivedInHistory") private var keepInHistory = true

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

    // MARK: - Card

    private func card(for transfer: Transfer) -> some View {
        let (emoji, name) = Peer.parseDisplayName(senderName(transfer))

        return VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 44))
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle(transfer))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Divider()

            content(transfer)

            Divider()

            keepToggle

            Divider()

            actionButtons(for: transfer)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .frame(maxWidth: 400)
        .padding(.horizontal, 24)
    }

    // MARK: - Keep-in-history toggle

    private var keepToggle: some View {
        Toggle(isOn: $keepInHistory) {
            Label("Keep in Transfer History", systemImage: "clock.arrow.circlepath")
                .font(.subheadline.weight(.medium))
        }
        .tint(.accentColor)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Actions

    private func actionButtons(for transfer: Transfer) -> some View {
        let rows = actionRows(transfer)
        return VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 10) {
                    ForEach(row) { action in
                        Button {
                            // Persisted intent applies to this transfer too:
                            // closing with the toggle off removes the record.
                            if !keepInHistory, let id = recordID(transfer) { onDeleteRecord(id) }
                            action.action()
                        } label: {
                            Text(action.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(action.isSecondary ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.accentColor))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.quaternary, in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
    }
}
