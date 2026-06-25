import SwiftUI

struct TextShareView: View {
    let onSend: (String) -> Void
    let onCancel: () -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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
                    onSend(text.trimmingCharacters(in: .whitespacesAndNewlines))
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
            }
        }
        .onAppear { isFocused = true }
    }
}

#Preview {
    TextShareView(onSend: { _ in }, onCancel: {})
}
