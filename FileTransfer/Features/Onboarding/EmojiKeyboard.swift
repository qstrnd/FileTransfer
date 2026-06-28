import SwiftUI
import UIKit

// MARK: - EmojiUITextField

final class EmojiUITextField: UITextField {
    override var textInputContextIdentifier: String? { "" }
    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" }
    }
}

// MARK: - EmojiKeyboard

/// Zero-size UIViewRepresentable that opens the emoji keyboard and forwards
/// the selected emoji to the parent via a Binding. Place it off-screen
/// (opacity 0, allowsHitTesting false) and toggle `isActive` to show/hide it.
struct EmojiKeyboard: UIViewRepresentable {
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
