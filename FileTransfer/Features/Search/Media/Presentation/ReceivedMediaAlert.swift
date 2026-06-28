import SwiftUI
import UIKit

struct ReceivedMediaAlert: View {
    let transfer: ReceivedMediaTransfer?
    let onDismiss: () -> Void
    let onSaveToGallery: ([ReceivedMediaItem]) async -> Bool
    let onSaveToFiles: ([ReceivedMediaItem]) -> Void
    let onShare: ([ReceivedMediaItem]) -> Void

    @State private var showSavedToast = false

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
            if showSavedToast {
                savedToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 12)
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(duration: 0.3), value: transfer?.id)
        .animation(.spring(duration: 0.35), value: showSavedToast)
        .onChange(of: transfer?.id) { _, newID in if newID != nil { showSavedToast = false } }
    }

    // MARK: - Card

    private func alertCard(for transfer: ReceivedMediaTransfer) -> some View {
        let (emoji, name) = Peer.parseDisplayName(transfer.senderName)

        return VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 44))
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("sent you media")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Divider()

            mediaSection(for: transfer.items)

            Divider()

            VStack(spacing: 0) {
                Button {
                    saveToGallery(transfer.items)
                } label: {
                    Text("Save to Gallery")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }

                Divider()

                Button {
                    onSaveToFiles(transfer.items)
                    onDismiss()
                } label: {
                    Text("Save to Files")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }

                Divider()

                Button {
                    onShare(transfer.items)
                    onDismiss()
                } label: {
                    Text("Share…")
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
        .padding(.horizontal, 24)
    }

    // MARK: - Media section

    @ViewBuilder
    private func mediaSection(for items: [ReceivedMediaItem]) -> some View {
        if items.count == 1, let item = items.first {
            Image(uiImage: item.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    if item.isVideo { videoOverlay.clipShape(RoundedRectangle(cornerRadius: 12)) }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        ZStack {
                            Image(uiImage: item.thumbnail)
                                .resizable()
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
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
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
