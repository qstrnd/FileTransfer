import SwiftUI
import UIKit

// MARK: - Emoji keyboard bridge

private final class EmojiUITextField: UITextField {
    override var textInputContextIdentifier: String? { "" }
    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" }
    }
}

private struct EmojiKeyboard: UIViewRepresentable {
    @Binding var isActive: Bool
    @Binding var emoji: String
    var onPicked: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> EmojiUITextField {
        let field = EmojiUITextField()
        field.delegate = context.coordinator
        field.returnKeyType = .next
        return field
    }

    func updateUIView(_ uiView: EmojiUITextField, context: Context) {
        if isActive, !uiView.isFirstResponder {
            // Defer past the current layout pass. Re-check isActive before acting:
            // if the emoji was picked before this task runs the binding will already
            // be false and we must not steal focus back from the name field.
            Task { @MainActor in
                guard isActive else { return }
                uiView.becomeFirstResponder()
            }
        } else if !isActive, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    @MainActor
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiKeyboard
        init(_ parent: EmojiKeyboard) { self.parent = parent }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let valid = OnboardingViewModel.isValidEmoji(string)
            textField.text = ""
            textField.resignFirstResponder() // triggers textFieldDidEndEditing → isActive = false
            if valid {
                parent.emoji = string
                parent.onPicked()
            }
            return false
        }

        // Covers every path by which the field can lose focus (emoji picked,
        // return key, user tapping elsewhere). Ensures isActive is always false
        // once the field is no longer first responder, so updateUIView never
        // schedules a stale becomeFirstResponder task.
        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.isActive = false
        }

        // "Next" return key — advance to name field without changing emoji.
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder() // triggers textFieldDidEndEditing → isActive = false
            parent.onPicked()
            return true
        }
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel
    var namespace: Namespace.ID

    init(onProceed: @escaping (String, String) -> Void, namespace: Namespace.ID) {
        _viewModel = State(initialValue: OnboardingViewModel(onProceed: onProceed))
        self.namespace = namespace
    }

    @FocusState private var isNameFocused: Bool
    @State private var isEmojiPickerActive = false

    private var isKeyboardVisible: Bool { isNameFocused || isEmojiPickerActive }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                identitySection

                Spacer(minLength: 0)

                if !isKeyboardVisible {
                    subtitleSection
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                bottomBar
            }
            .animation(.easeOut(duration: 0.25), value: isKeyboardVisible)
        }
        .overlay(alignment: .topLeading) {
            EmojiKeyboard(
                isActive: $isEmojiPickerActive,
                emoji: Binding(
                    get: { viewModel.emoji },
                    set: { viewModel.emojiSelectedByUser($0) }
                ),
                onPicked: { isNameFocused = true }
            )
                .frame(width: 1, height: 1)
                .opacity(0)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isNameFocused = false
            isEmojiPickerActive = false
        }
    }

    // MARK: Identity

    private var identitySection: some View {
        VStack(spacing: 24) {
            Button {
                isNameFocused = false
                isEmojiPickerActive = true
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 128, height: 128)
                        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 2)
                    Text(viewModel.emoji)
                        .font(.system(size: 64))
                }
                .matchedGeometryEffect(id: "heroCircle", in: namespace)
            }
            .buttonStyle(.plain)

            TextField("Your name", text: Binding(
                    get: { viewModel.name },
                    set: { viewModel.nameEditedByUser(to: $0) }
                ))
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
                .focused($isNameFocused)
                .submitLabel(.done)
                .onSubmit { isNameFocused = false }
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 32)
    }

    // MARK: Subtitle

    private var subtitleSection: some View {
        Text("Choose how your device\nis visible to others")
            .font(.title3)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 0) {
            if !isKeyboardVisible {
                Button {
                    withAnimation(.spring(duration: 0.3)) { viewModel.randomize() }
                } label: {
                    iconButtonLabel("dice.fill")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))

                Spacer()

                if viewModel.source != .device {
                    Button {
                        withAnimation(.spring(duration: 0.3)) { viewModel.useDeviceInfo() }
                    } label: {
                        Text("Device Info")
                            .font(.body)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(.white, in: Capsule())
                            .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 1)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))

                    Spacer()
                }
            } else {
                Spacer()
            }

            Button {
                viewModel.proceed()
            } label: {
                iconButtonLabel("checkmark", primary: true)
            }
            .disabled(!viewModel.canProceed)
            .opacity(viewModel.canProceed ? 1 : 0.4)
        }
        .animation(.spring(duration: 0.3), value: isKeyboardVisible)
        .animation(.spring(duration: 0.3), value: viewModel.source)
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    private func iconButtonLabel(_ symbol: String, primary: Bool = false) -> some View {
        Image(systemName: symbol)
            .font(.body.weight(.semibold))
            .foregroundStyle(primary ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .padding(16)
            .background(primary ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.white), in: Circle())
            .shadow(color: .black.opacity(primary ? 0.2 : 0.07), radius: 6, x: 0, y: 1)
    }
}

#Preview {
    @Previewable @Namespace var ns
    OnboardingView(onProceed: { _, _ in }, namespace: ns)
}
