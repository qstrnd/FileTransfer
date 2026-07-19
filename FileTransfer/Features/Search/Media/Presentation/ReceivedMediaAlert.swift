import SwiftUI
import UIKit

struct ReceivedMediaAlert: View {
    let transfer: ReceivedMediaTransfer?
    let thumbnailGate: any ThumbnailGate
    let onDismiss: () -> Void
    let onSaveToGallery: ([ReceivedMediaItem]) async -> Bool
    let onSaveToFiles: ([ReceivedMediaItem]) -> Void
    let onShare: ([ReceivedMediaItem]) -> Void

    @State private var showSavedToast = false

    var body: some View {
        ZStack {
            ReceivedTransferAlert(
                transfer: transfer,
                senderName: { $0.senderName },
                subtitle: { _ in "sent you media" },
                content: { mediaSection(for: $0.items) },
                actionRows: { transfer in
                    [
                        [
                            ReceivedAlertAction(title: "Save to Gallery") {
                                saveToGallery(transfer.items)
                            },
                            ReceivedAlertAction(title: "Save to Files") {
                                onSaveToFiles(transfer.items)
                                onDismiss()
                            },
                        ],
                        [
                            ReceivedAlertAction(title: "Share") {
                                onShare(transfer.items)
                                onDismiss()
                            },
                        ],
                        [
                            ReceivedAlertAction(title: "Close") {
                                onDismiss()
                            },
                        ],
                    ]
                }
            )

            if showSavedToast {
                savedToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 12)
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(duration: 0.35), value: showSavedToast)
        .onChange(of: transfer?.id) { _, newID in if newID != nil { showSavedToast = false } }
    }

    // MARK: - Media section

    @ViewBuilder
    private func mediaSection(for items: [ReceivedMediaItem]) -> some View {
        if items.count == 1, let item = items.first {
            MediaThumbnailView(item: item, gate: thumbnailGate)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    if item.isVideo { videoOverlay.clipShape(RoundedRectangle(cornerRadius: 12)) }
                }
                .overlay(alignment: .topLeading) {
                    if item.isLivePhoto { livePhotoBadge.padding(8) }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        ZStack(alignment: .topLeading) {
                            MediaThumbnailView(item: item, gate: thumbnailGate)
                                .scaledToFill()
                                .frame(width: 160, height: 160)
                                .clipped()
                                .cornerRadius(12)
                            if item.isVideo {
                                videoOverlay
                                    .frame(width: 160, height: 160)
                                    .cornerRadius(12)
                                    .allowsHitTesting(false)
                            }
                            if item.isLivePhoto { livePhotoBadge.padding(6) }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
    }

    private var livePhotoBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "livephoto")
                .font(.system(size: 12, weight: .semibold))
            Text("LIVE")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var videoOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
            Image(systemName: "play.fill")
                .foregroundStyle(.white)
                .font(.system(size: 28))
        }
    }

    // MARK: - Toast

    private var savedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 17, weight: .semibold))
            Text("Saved!")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }

    // MARK: - Private

    private func saveToGallery(_ items: [ReceivedMediaItem]) {
        Task { @MainActor in
            let saved = await onSaveToGallery(items)
            if saved { showSavedToast = true }
            try? await Task.sleep(for: .seconds(saved ? 1.5 : 0))
            showSavedToast = false
            onDismiss()
        }
    }
}

// MARK: - MediaThumbnailView

private struct MediaThumbnailView: View {
    let item: ReceivedMediaItem
    let gate: any ThumbnailGate
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable()
            } else {
                Color.gray.opacity(0.15)
                    .overlay { ProgressView() }
            }
        }
        .task(id: item.id) {
            // Data → UIImage conversion happens here at the Presentation boundary.
            if let data = await gate.thumbnail(for: item.fileURL, isVideo: item.isVideo) {
                image = UIImage(data: data)
            }
        }
    }
}
