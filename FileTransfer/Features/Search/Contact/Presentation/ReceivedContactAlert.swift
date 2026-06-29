import SwiftUI

struct ReceivedContactAlert: View {
    let transfer: ReceivedContactTransfer?
    let onDismiss: () -> Void
    let onShare: (Data) -> Void

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

    // MARK: - Card

    private func alertCard(for transfer: ReceivedContactTransfer) -> some View {
        let (emoji, name) = Peer.parseDisplayName(transfer.senderName)
        let contactWord = transfer.contacts.count == 1 ? "a contact" : "\(transfer.contacts.count) contacts"

        return VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 44))
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("sent you \(contactWord)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Divider()

            contactSection(for: transfer.contacts)

            Divider()

            VStack(spacing: 0) {
                Button {
                    onShare(transfer.vCardData)
                    onDismiss()
                } label: {
                    Label("Share…", systemImage: "square.and.arrow.up")
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

    // MARK: - Contact list

    @ViewBuilder
    private func contactSection(for contacts: [ContactItem]) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(contacts) { contact in
                    contactRow(contact)
                    if contact.id != contacts.last?.id {
                        Divider().padding(.leading, 72)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 280)
    }

    private func contactRow(_ contact: ContactItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(.tint.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(contact.displayName.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.tint)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.subheadline.weight(.semibold))
                if let phone = contact.phoneNumbers.first {
                    Text(phone)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let email = contact.emailAddresses.first {
                    Text(email)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Received — single contact") {
    let transfer = ReceivedContactTransfer(
        senderName: "🦒 Cunning Giraffe",
        contacts: [ContactItem(displayName: "Jane Smith", phoneNumbers: ["+1 555 123 4567"], emailAddresses: ["jane@example.com"])],
        vCardData: Data()
    )
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        ReceivedContactAlert(transfer: transfer, onDismiss: {}, onShare: { _ in })
    }
}

#Preview("Received — multiple contacts") {
    let transfer = ReceivedContactTransfer(
        senderName: "🐺 Puffy Wolf",
        contacts: [
            ContactItem(displayName: "Alice Johnson", phoneNumbers: ["+1 555 000 1111"], emailAddresses: []),
            ContactItem(displayName: "Bob Martinez", phoneNumbers: [], emailAddresses: ["bob@example.com"]),
            ContactItem(displayName: "Carol White", phoneNumbers: ["+44 20 1234 5678"], emailAddresses: ["carol@example.com"]),
        ],
        vCardData: Data()
    )
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        ReceivedContactAlert(transfer: transfer, onDismiss: {}, onShare: { _ in })
    }
}

#Preview("Hidden") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        ReceivedContactAlert(transfer: nil, onDismiss: {}, onShare: { _ in })
    }
}
#endif
