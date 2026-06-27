import SwiftUI

struct MediaPreviewView: View {
    @Binding var items: [MediaItem]
    let hasConnections: Bool
    let onSend: ([MediaItem]) -> Void
    let onCancel: () -> Void
    let onAddMore: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    private var canSend: Bool { hasConnections && !items.isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(items) { item in
                            thumbnailCell(for: item)
                        }
                        addMoreCell
                    }
                    .padding(2)
                }

                Divider()

                Button {
                    onSend(items)
                } label: {
                    Text("Send")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            canSend ? Color.accentColor : Color.accentColor.opacity(0.35),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                }
                .disabled(!canSend)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("Share Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }

    @ViewBuilder
    private func thumbnailCell(for item: MediaItem) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                Image(uiImage: item.thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.width)
                    .clipped()

                if item.isVideo {
                    ZStack {
                        Color.black.opacity(0.3)
                        Image(systemName: "play.fill")
                            .foregroundStyle(.white)
                            .font(.system(size: 24))
                    }
                    .frame(width: geo.size.width, height: geo.size.width)
                    .allowsHitTesting(false)
                }

                Button {
                    items.removeAll { $0.id == item.id }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 22))
                        .shadow(color: .black.opacity(0.4), radius: 2)
                }
                .padding(4)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var addMoreCell: some View {
        Button(action: onAddMore) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary, style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.secondary)
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }
}
