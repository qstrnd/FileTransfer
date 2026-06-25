import SwiftUI

struct TextShareView: View {
    let onSend: (String) -> Void
    let onCancel: () -> Void

    @AppStorage("textShareDraft") private var text = ""
    @FocusState private var isFocused: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasContent: Bool { !trimmed.isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $text)
                    .font(.body)
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .focused($isFocused)

                Divider()

                Button {
                    let toSend = trimmed
                    text = ""           // clear persisted draft on send
                    onSend(toSend)
                } label: {
                    Text("Send")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            hasContent ? Color.accentColor : Color.accentColor.opacity(0.35),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                }
                .disabled(!hasContent)
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
                if hasContent {
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

#Preview {
    TextShareView(onSend: { _ in }, onCancel: {})
}
