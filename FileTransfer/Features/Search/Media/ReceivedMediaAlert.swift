import SwiftUI
import Photos
import UIKit

struct ReceivedMediaTransfer: Identifiable {
    let id = UUID()
    let senderName: String
    let items: [ReceivedMediaItem]
}

struct ReceivedMediaAlert: View {
    let transfer: ReceivedMediaTransfer?
    let onDismiss: () -> Void

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
        let emoji = String(transfer.senderName.prefix(1))
        let name: String = {
            guard let idx = transfer.senderName.firstIndex(of: " ") else { return transfer.senderName }
            return String(transfer.senderName[transfer.senderName.index(after: idx)...])
        }()

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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(transfer.items) { item in
                        ZStack {
                            Image(uiImage: item.thumbnail)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 160, height: 160)
                                .clipped()
                                .cornerRadius(12)

                            if item.isVideo {
                                ZStack {
                                    Color.black.opacity(0.3)
                                    Image(systemName: "play.fill")
                                        .foregroundStyle(.white)
                                        .font(.system(size: 28))
                                }
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
                    saveToFiles(transfer.items)
                } label: {
                    Text("Save to Files")
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

    // MARK: - Actions

    private func saveToGallery(_ items: [ReceivedMediaItem]) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                for item in items {
                    if item.isVideo {
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: item.fileURL)
                    } else {
                        PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: item.fileURL)
                    }
                }
            } completionHandler: { success, _ in
                guard success else { return }
                Task { @MainActor in
                    showSavedToast = true
                    try? await Task.sleep(for: .seconds(2))
                    showSavedToast = false
                }
            }
        }
    }

    private func saveToFiles(_ items: [ReceivedMediaItem]) {
        let urls = items.map(\.fileURL)
        guard !urls.isEmpty else { return }
        let docPicker = UIDocumentPickerViewController(forExporting: urls, asCopy: true)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        var presenter = rootVC
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(docPicker, animated: true)
    }
}
