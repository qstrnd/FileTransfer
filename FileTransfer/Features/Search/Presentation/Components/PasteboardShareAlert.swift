import SwiftUI

/// Confirmation shown before sharing the pasteboard. Previews what will be sent
/// — text, image(s), or document(s) — so the user explicitly taps Share to
/// consent. Mirrors the modal-scrim glass card used by the received alerts.
struct PasteboardShareAlert: View {
    /// Nil hides the alert; the view stays mounted so transitions play.
    let content: PasteboardShareContent?
    let onCancel: () -> Void
    let onShare: () -> Void

    private let cardCornerRadius: CGFloat = 20

    var body: some View {
        ZStack {
            if content != nil {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture(perform: onCancel)
            }
            if let content {
                card(for: content)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(duration: 0.3), value: content?.id)
    }

    // MARK: - Card

    private func card(for content: PasteboardShareContent) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Image(systemName: "document.on.clipboard.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.tint)
                Text("Sharing Pasteboard Content")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(subtitle(for: content))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Divider()

            preview(for: content)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            Divider()

            actionButtons
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .frame(maxWidth: 400)
        .padding(.horizontal, 24)
    }

    private func subtitle(for content: PasteboardShareContent) -> String {
        switch content {
        case .text:
            "Text"
        case .images(let urls):
            urls.count == 1 ? "1 image" : "\(urls.count) images"
        case .files(let files):
            files.count == 1 ? "1 document" : "\(files.count) documents"
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private func preview(for content: PasteboardShareContent) -> some View {
        switch content {
        case .text(let text):
            ScrollView {
                Text(text)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 160)

        case .images(let urls):
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(urls, id: \.self) { url in
                        imageThumbnail(url)
                    }
                }
            }
            .frame(height: 120)

        case .files(let files):
            VStack(spacing: 10) {
                ForEach(files) { file in
                    HStack(spacing: 12) {
                        Image(systemName: file.systemImage)
                            .font(.title3)
                            .foregroundStyle(.tint)
                            .frame(width: 28)
                        Text(file.name)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func imageThumbnail(_ url: URL) -> some View {
        Group {
            if let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: 10) {
            button(title: "Cancel", isSecondary: true, action: onCancel)
            button(title: "Share", isSecondary: false, action: onShare)
        }
        .padding(16)
    }

    private func button(title: String, isSecondary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(isSecondary ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.regularMaterial, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
