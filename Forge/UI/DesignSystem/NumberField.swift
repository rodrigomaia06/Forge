//
//  NumberField.swift
//  Forge
//
//  A numeric entry field that is always edited from the right, like a calculator: the value is
//  right-aligned and the caret is pinned to the end so digits can only be added or removed at the
//  right. The whole box is the tap target (a UITextField fills its frame), and the placeholder (used
//  for a planned rep range) shows inside the box when it is empty.
//

import SwiftUI
import UIKit

private final class PaddedTextField: UITextField {
    private let inset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
    override func textRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: inset) }
    override func editingRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: inset) }
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: inset) }
}

struct RightAlignedNumberField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .decimalPad
    /// Centered in the compact set boxes; trailing in labeled form rows. The caret is pinned to the end
    /// either way, so the value is always edited from the right.
    var alignment: NSTextAlignment = .center
    /// The compact set boxes use a small placeholder (the rep-range hint); form rows use the full value
    /// size so a "0" placeholder isn't tiny.
    var smallPlaceholder: Bool = true
    /// Called when editing ends (the field resigns focus). Lets a caller persist the value once per edit
    /// instead of on every keystroke, which keeps a single character from churning the whole screen.
    var onCommit: () -> Void = {}

    private static func valueFont() -> UIFont {
        // Matches `.forgeValue`: rounded, monospaced digits, at the body text size, scaled for Dynamic
        // Type (with adjustsFontForContentSizeCategory the field keeps up with the current size).
        var font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular)
        if let descriptor = font.fontDescriptor.withDesign(.rounded) {
            font = UIFont(descriptor: descriptor, size: 17)
        }
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: font)
    }

    /// A Done bar above the keyboard, built here in UIKit rather than with SwiftUI's `.keyboard` toolbar
    /// placement.
    ///
    /// SwiftUI only shows a keyboard toolbar for a field it owns and tracks focus for. This is a
    /// UITextField behind a UIViewRepresentable, so SwiftUI never knows it is first responder and the
    /// toolbar never appeared. With the lists no longer dismissing the keyboard when scrolled, that left
    /// a number pad with no way out at all: it has no return key. An input accessory view belongs to the
    /// field itself, so it always shows.
    private static func doneBar(target: Coordinator) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "Done", style: .done, target: target, action: #selector(Coordinator.dismissKeyboard)),
        ]
        toolbar.sizeToFit()
        return toolbar
    }

    func makeUIView(context: Context) -> UITextField {
        let field = PaddedTextField()
        field.delegate = context.coordinator
        field.inputAccessoryView = Self.doneBar(target: context.coordinator)
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        field.textAlignment = alignment
        field.font = Self.valueFont()
        field.adjustsFontForContentSizeCategory = true
        field.textColor = .label
        field.tintColor = .label
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    /// Assigns only what actually changed.
    ///
    /// Both of these used to be written on every SwiftUI update, and an update here is not rare:
    /// committing a value in one set row publishes a Core Data change that fans out across the whole
    /// workout, so every field in every row is updated, the focused one included. Assigning
    /// `keyboardType` to a field that is first responder makes UIKit reload its input views, which
    /// posts a keyboard notification, which drives another update. A recorded freeze caught the shape
    /// of it: three keyboardWillShow in a row with no hide between them, two hides 18ms apart, and
    /// then the main thread stopped answering.
    ///
    /// Rebuilding `attributedPlaceholder` every time also allocated a new attributed string and
    /// re-laid out the field for a value that almost never changes.
    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        if field.keyboardType != keyboardType { field.keyboardType = keyboardType }

        // The placeholder (a planned rep range like "8-12") is smaller than the value so it fits the
        // narrow box and reads as a hint rather than an entered number. The content size category is
        // part of the identity so it still follows Dynamic Type.
        let wanted = PlaceholderStyle(
            text: placeholder,
            small: smallPlaceholder,
            contentSize: field.traitCollection.preferredContentSizeCategory
        )
        if context.coordinator.appliedPlaceholder != wanted {
            context.coordinator.appliedPlaceholder = wanted
            field.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [
                    .font: smallPlaceholder ? UIFont.preferredFont(forTextStyle: .footnote) : Self.valueFont(),
                    .foregroundColor: UIColor.secondaryLabel,
                ]
            )
        }
    }

    /// What the field's placeholder was last built from, so it is only rebuilt when one of them moves.
    struct PlaceholderStyle: Equatable {
        let text: String
        let small: Bool
        let contentSize: UIContentSizeCategory
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: RightAlignedNumberField
        var appliedPlaceholder: PlaceholderStyle?
        init(_ parent: RightAlignedNumberField) { self.parent = parent }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
            moveCaretToEnd(field)
        }

        @objc func dismissKeyboard() {
            HangMonitor.note("keyboard done tapped")
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        func textFieldDidBeginEditing(_ field: UITextField) {
            HangMonitor.note("value field focused")
            moveCaretToEnd(field)
        }

        func textFieldDidEndEditing(_ field: UITextField) {
            HangMonitor.note("value field ended editing")
            parent.text = field.text ?? ""
            parent.onCommit()
        }

        /// Keeps the caret at the end, so a value is edited from the right like a calculator.
        ///
        /// Driven only by our own edits: focus arriving, and text changing. It used to hook
        /// `textFieldDidChangeSelection`, which observes UIKit's selection changes and moved the caret
        /// back in response to them. The re-entrancy guard there only covered a synchronous callback,
        /// and UIKit re-establishes selection on a later turn of the run loop, by which time the guard
        /// was down again. The two could then trade selection changes without end and wedge the main
        /// thread, which is what a recorded freeze looks like: the keyboard resigning, a value
        /// committing, and then nothing.
        ///
        /// The trade-off is that tapping into the middle of an already-focused value now leaves the
        /// caret where it was put, instead of snapping back to the end.
        private func moveCaretToEnd(_ field: UITextField) {
            let end = field.endOfDocument
            guard let range = field.textRange(from: end, to: end), field.selectedTextRange != range else { return }
            field.selectedTextRange = range
        }
    }
}
