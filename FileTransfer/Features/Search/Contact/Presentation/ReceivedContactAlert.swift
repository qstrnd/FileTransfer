import SwiftUI
import UIKit

struct ReceivedContactAlert: View {
    let transfer: ReceivedContactTransfer?
    let onDismiss: () -> Void
    let onShare: (Data) -> Void

    private let cardCornerRadius: CGFloat = 20

    private func initials(for name: String) -> String {
        name.split(separator: " ").prefix(2)
            .compactMap(\.first).map(String.init).joined()
    }

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
            avatar(for: contact)

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

    // MARK: - Avatar

    /// Uses the sender's actual contact photo when one was shared; falls back
    /// to an initials-on-color circle otherwise.
    @ViewBuilder
    private func avatar(for contact: ContactItem) -> some View {
        if let data = contact.photoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(ContactColor.assigned(for: contact.displayName).backgroundSwiftUIColor)
                .frame(width: 44, height: 44)
                .overlay {
                    Text(initials(for: contact.displayName))
                        .font(.headline)
                        .foregroundStyle(ContactColor.assigned(for: contact.displayName).swiftUIColor)
                }
        }
    }
}

// MARK: - Previews

#if DEBUG
private func previewPhoto(_ color: UIColor) -> Data {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120))
    return renderer.jpegData(withCompressionQuality: 0.9) { ctx in
        color.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 120, height: 120))
    }
}

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

#Preview("Received — with photo") {
    let transfer = ReceivedContactTransfer(
        senderName: "🦊 Fox",
        contacts: [
            ContactItem(displayName: "Jane Smith", phoneNumbers: ["+1 555 123 4567"], emailAddresses: [], photoData: previewPhoto(.systemOrange)),
            ContactItem(displayName: "No Photo Guy", phoneNumbers: ["+1 555 999 0000"], emailAddresses: []),
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
