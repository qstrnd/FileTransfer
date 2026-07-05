#if DEBUG
import SwiftUI
import UIKit

/// One-stop gallery of every "received/sending" alert overlay used in
/// SearchView (see the `.background(PinnedWindow(...))` chain there), each
/// fed with realistic mock content — long text, photos, a video, a live
/// photo, documents of several types, and contacts with/without photos.
///
/// Individual alert files keep their own minimal previews for quick
/// iteration; this file is the place to check how every alert actually
/// looks with representative, varied content in one pass.

// MARK: - Fake gates (no disk I/O — safe for fake `file:///gallery/...` URLs)

private final class GalleryDocumentThumbnailGate: HistoryThumbnailGate, @unchecked Sendable {
    private let palette: [UIColor] = [
        UIColor(red: 0.36, green: 0.58, blue: 0.93, alpha: 1),
        UIColor(red: 0.30, green: 0.73, blue: 0.54, alpha: 1),
        UIColor(red: 0.96, green: 0.62, blue: 0.28, alpha: 1),
        UIColor(red: 0.72, green: 0.47, blue: 0.89, alpha: 1),
        UIColor(red: 0.93, green: 0.38, blue: 0.38, alpha: 1),
    ]

    func thumbnail(for url: URL) async -> Data? {
        let color = palette[abs(url.absoluteString.hashValue) % palette.count]
        let size = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.jpegData(withCompressionQuality: 0.85) { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    func prefetch(_ urls: [URL]) {}
}

private final class GalleryMediaThumbnailGate: ThumbnailGate, @unchecked Sendable {
    private let palette: [UIColor] = [
        UIColor(red: 0.98, green: 0.75, blue: 0.36, alpha: 1), // sunset gold
        UIColor(red: 0.35, green: 0.62, blue: 0.87, alpha: 1), // sky blue
        UIColor(red: 0.45, green: 0.71, blue: 0.44, alpha: 1), // forest green
        UIColor(red: 0.85, green: 0.45, blue: 0.55, alpha: 1), // dusty pink
    ]

    func thumbnail(for url: URL, isVideo: Bool) async -> Data? {
        let color = palette[abs(url.absoluteString.hashValue) % palette.count]
        let size = CGSize(width: 600, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.jpegData(withCompressionQuality: 0.85) { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Mock helpers

private func galleryURL(_ name: String) -> URL { URL(string: "file:///gallery/\(name)")! }

private func galleryPhoto(_ color: UIColor) -> Data {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120))
    return renderer.jpegData(withCompressionQuality: 0.9) { ctx in
        color.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 120, height: 120))
    }
}

private let longMessage = """
Hey! Just wanted to send a quick update on where things stand with the project. \
We finished the first draft of the proposal, reviewed it with the team, and \
incorporated most of the feedback from last week's call. There are still a \
couple of open questions around timeline and budget that we should probably \
discuss live rather than over text — do you have 15 minutes tomorrow morning? \
Let me know what works and I'll send a calendar invite.
"""

// MARK: - Text

#Preview("Alert — long text") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        ReceivedTextAlert(
            message: TransferMessage(senderName: "🦉 Wise Owl", text: longMessage),
            onDismiss: {},
            onCopied: {}
        )
    }
}

// MARK: - Media (images)

#Preview("Alert — media (photos)") {
    let items = [
        ReceivedMediaItem(fileURL: galleryURL("sunset.heic"), isVideo: false, livePhotoVideoURL: nil, fileName: "sunset.heic"),
        ReceivedMediaItem(fileURL: galleryURL("mountains.jpg"), isVideo: false, livePhotoVideoURL: nil, fileName: "mountains.jpg"),
        ReceivedMediaItem(fileURL: galleryURL("beach.jpg"), isVideo: false, livePhotoVideoURL: nil, fileName: "beach.jpg"),
        ReceivedMediaItem(fileURL: galleryURL("forest.jpg"), isVideo: false, livePhotoVideoURL: nil, fileName: "forest.jpg"),
    ]
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        ReceivedMediaAlert(
            transfer: ReceivedMediaTransfer(senderName: "🐨 Koala", items: items),
            thumbnailGate: GalleryMediaThumbnailGate(),
            onDismiss: {},
            onSaveToGallery: { _ in true },
            onSaveToFiles: { _ in },
            onShare: { _ in }
        )
    }
}

// MARK: - Media (video + live photo)

#Preview("Alert — media (video + live photo)") {
    let items = [
        ReceivedMediaItem(fileURL: galleryURL("clip.mov"), isVideo: true, livePhotoVideoURL: nil, fileName: "clip.mov"),
        ReceivedMediaItem(fileURL: galleryURL("live1.heic"), isVideo: false, livePhotoVideoURL: galleryURL("live1.mov"), fileName: "live1.heic"),
        ReceivedMediaItem(fileURL: galleryURL("photo1.jpg"), isVideo: false, livePhotoVideoURL: nil, fileName: "photo1.jpg"),
    ]
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        ReceivedMediaAlert(
            transfer: ReceivedMediaTransfer(senderName: "🦔 Hedgehog", items: items),
            thumbnailGate: GalleryMediaThumbnailGate(),
            onDismiss: {},
            onSaveToGallery: { _ in true },
            onSaveToFiles: { _ in },
            onShare: { _ in }
        )
    }
}

// MARK: - Files (single document)

#Preview("Alert — files (single document)") {
    let files = [ReceivedFile(url: galleryURL("Q3_Report.pdf"), name: "Q3_Report.pdf")]
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        ReceivedFileAlert(
            transfer: ReceivedFileTransfer(senderName: "🦁 Lion", files: files),
            thumbnailGate: GalleryDocumentThumbnailGate(),
            onDismiss: {},
            onSaveToFiles: { _ in },
            onShare: { _ in }
        )
    }
}

// MARK: - Files (multiple documents)

#Preview("Alert — files (multiple documents)") {
    let files = [
        ReceivedFile(url: galleryURL("Q3_Report.pdf"), name: "Q3_Report.pdf"),
        ReceivedFile(url: galleryURL("Proposal.docx"), name: "Proposal.docx"),
        ReceivedFile(url: galleryURL("Budget.xlsx"), name: "Budget.xlsx"),
        ReceivedFile(url: galleryURL("Slides.pptx"), name: "Slides.pptx"),
        ReceivedFile(url: galleryURL("Archive.zip"), name: "Archive.zip"),
    ]
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        ReceivedFileAlert(
            transfer: ReceivedFileTransfer(senderName: "🦁 Lion", files: files),
            thumbnailGate: GalleryDocumentThumbnailGate(),
            onDismiss: {},
            onSaveToFiles: { _ in },
            onShare: { _ in }
        )
    }
}

// MARK: - Contact (single, with photo)

#Preview("Alert — contact (with photo)") {
    let transfer = ReceivedContactTransfer(
        senderName: "🦊 Fox",
        contacts: [
            ContactItem(displayName: "Jane Smith", phoneNumbers: ["+1 555 123 4567"],
                        emailAddresses: ["jane@example.com"], photoData: galleryPhoto(.systemOrange)),
        ],
        vCardData: Data()
    )
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        ReceivedContactAlert(transfer: transfer, onDismiss: {}, onShare: { _ in })
    }
}

// MARK: - Contacts (multiple, mixed photos)

#Preview("Alert — contacts (multiple, mixed photos)") {
    let transfer = ReceivedContactTransfer(
        senderName: "🐺 Puffy Wolf",
        contacts: [
            ContactItem(displayName: "Alice Johnson", phoneNumbers: ["+1 555 000 1111"],
                        emailAddresses: [], photoData: galleryPhoto(.systemBlue)),
            ContactItem(displayName: "Bob Martinez", phoneNumbers: [], emailAddresses: ["bob@example.com"]),
            ContactItem(displayName: "Carol White", phoneNumbers: ["+44 20 1234 5678"],
                        emailAddresses: ["carol@example.com"], photoData: galleryPhoto(.systemGreen)),
        ],
        vCardData: Data()
    )
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        ReceivedContactAlert(transfer: transfer, onDismiss: {}, onShare: { _ in })
    }
}

// MARK: - Invitation

#Preview("Alert — invitation") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        InvitationAlert(peer: Peer(displayName: "🦙 Happy Llama"), onAccept: {}, onDecline: {})
    }
}

// MARK: - Sending (in progress / complete)

#Preview("Alert — sending (in progress)") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        SendingTransferAlert(
            transfer: SendingTransferStatus(id: UUID(), totalItems: 5, peerCount: 2, isComplete: false, progress: 0.42),
            onAbort: {}
        )
    }
}

#Preview("Alert — sending (complete)") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        SendingTransferAlert(
            transfer: SendingTransferStatus(id: UUID(), totalItems: 5, peerCount: 2, isComplete: true, progress: 1),
            onAbort: {}
        )
    }
}
#endif
