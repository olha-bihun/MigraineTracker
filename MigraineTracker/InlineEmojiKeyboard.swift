import SwiftUI

#if canImport(UIKit)
import UIKit

struct InlineEmojiKeyboard: UIViewRepresentable {
    @Binding var isPresented: Bool
    @Binding var selection: String

    final class EmojiField: UITextField {
        override var textInputContextIdentifier: String? { "diary-emoji" }
        override var textInputMode: UITextInputMode? {
            UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: InlineEmojiKeyboard
        init(_ parent: InlineEmojiKeyboard) { self.parent = parent }
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard EmojiChoice.isValid(string) else { return false }
            parent.selection = string
            parent.isPresented = false
            textField.resignFirstResponder()
            return false
        }
        func textFieldDidEndEditing(_ textField: UITextField) {
            DispatchQueue.main.async { self.parent.isPresented = false }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> EmojiField {
        let field = EmojiField()
        field.delegate = context.coordinator
        field.tintColor = .clear
        field.textColor = .clear
        field.inputAssistantItem.leadingBarButtonGroups = []
        field.inputAssistantItem.trailingBarButtonGroups = []
        field.isAccessibilityElement = false
        return field
    }
    func updateUIView(_ field: EmojiField, context: Context) {
        context.coordinator.parent = self
        if isPresented && !field.isFirstResponder {
            DispatchQueue.main.async {
                guard context.coordinator.parent.isPresented, field.window != nil else { return }
                field.becomeFirstResponder()
            }
        } else if !isPresented && field.isFirstResponder { field.resignFirstResponder() }
    }
}
#else
struct InlineEmojiKeyboard: View {
    @Binding var isPresented: Bool
    @Binding var selection: String
    var body: some View { EmptyView() }
}
#endif
