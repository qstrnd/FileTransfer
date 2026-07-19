import SwiftUI

/// One button in a received-transfer alert's action list.
struct ReceivedAlertAction: Identifiable {
    let id = UUID()
    let title: String
    let action: () -> Void
}

/// Shared chrome for the "you received X" alerts (media / file / text / contact).
///
/// Owns the modal scrim, glass card, sender header, the history-retention
/// notice, and the action-button list, so the received-transfer alerts stay
/// visually and behaviourally unified. Each specific alert supplies only its
/// subtitle, preview content, and actions.
///
/// The history record for the transfer is created on receipt and kept for the
/// duration set in the history-retention setting; the notice below the content
/// tells the user how long that is (or that history is off).
struct ReceivedTransferAlert<Transfer: Identifiable, Content: View>: View {
    /// Nil hides the alert; the view stays in the hierarchy so transitions play.
    let transfer: Transfer?
    let senderName: (Transfer) -> String
    let subtitle: (Transfer) -> String
    @ViewBuilder let content: (Transfer) -> Content
    /// Action buttons grouped into rows; each row lays its buttons out as
    /// equal-width capsules side by side (e.g. `[[Save to Gallery, Save to
    /// Files], [Share], [Close]]`).
    let actionRows: (Transfer) -> [[ReceivedAlertAction]]

    @AppStorage("ft.historyRetentionDays") private var retentionDays = HistoryRetention.month.rawValue

    private let cardCornerRadius: CGFloat = 20

    private var retention: HistoryRetention { HistoryRetention(rawValue: retentionDays) ?? .month }

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

            retentionNotice

            Divider()

            actionButtons(for: transfer)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .frame(maxWidth: 400)
        .padding(.horizontal, 24)
    }

    // MARK: - History-retention notice

    private var retentionNotice: some View {
        Label {
            Text(retentionNoticeText)
        } icon: {
            Image(systemName: retention == .disabled ? "clock.badge.xmark" : "clock.arrow.circlepath")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var retentionNoticeText: String {
        switch retention {
        case .week:     "This transfer will be kept in Transfer History for 1 week."
        case .month:    "This transfer will be kept in Transfer History for 1 month."
        case .forever:  "This transfer will be kept in Transfer History."
        case .disabled: "This transfer won’t be saved to Transfer History."
        }
    }

    // MARK: - Actions

    private func actionButtons(for transfer: Transfer) -> some View {
        let rows = actionRows(transfer)
        return VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 10) {
                    ForEach(row) { action in
                        Button(action: action.action) {
                            Text(action.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.regularMaterial, in: Capsule())
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
