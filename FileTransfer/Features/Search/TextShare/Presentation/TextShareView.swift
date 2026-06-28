import SwiftUI

struct TextShareView: View {
    let onSend: (String) -> Void
    let onCancel: () -> Void
    let hasConnections: Bool

    @AppStorage("textShareDraft") private var text = ""
    @FocusState private var isFocused: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { hasConnections && !trimmed.isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .font(.body)
                        .padding(16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .focused($isFocused)

                    if text.isEmpty {
                        Text("Write a message to share…")
                            .font(.body)
                            .foregroundStyle(.placeholder)
                            .padding(EdgeInsets(top: 24, leading: 21, bottom: 0, trailing: 0))
                            .allowsHitTesting(false)
                    }
                }

                Divider()

                Button {
                    let toSend = trimmed
                    text = ""
                    onSend(toSend)
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
            .navigationTitle("Share Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                if !trimmed.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") { text = "" }
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear { isFocused = true }
    }
}

#Preview("With connections") {
    TextShareView(onSend: { _ in }, onCancel: {}, hasConnections: true)
}

#Preview("No connections") {
    TextShareView(onSend: { _ in }, onCancel: {}, hasConnections: false)
}
