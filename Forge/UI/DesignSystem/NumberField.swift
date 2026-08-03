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

    /// Numeric values in Forge edit like a calculator: a tap always resolves to the trailing edge and
    /// the insertion caret is always drawn there. This avoids observing and rewriting selection changes,
    /// which previously let UIKit and SwiftUI trade callbacks indefinitely while the keyboard was moving.
    override func closestPosition(to point: CGPoint) -> UITextPosition? { endOfDocument }
    override func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? { range.end }
    override func caretRect(for position: UITextPosition) -> CGRect { super.caretRect(for: endOfDocument) }
}

struct RightAlignedNumberField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .decimalPad
    /// A compact representation used only while the field is idle. The binding retains the complete
    /// editable text, which is restored as soon as focus arrives.
    var displayText: String? = nil
    /// Stable, value-free semantics for VoiceOver and UI automation. Callers must describe the field's
    /// role, never the value or a model identifier.
    var accessibilityLabel: String? = nil
    /// Centered in the compact set boxes; trailing in labeled form rows. The caret is pinned to the end
    /// either way, so the value is always edited from the right.
    var alignment: NSTextAlignment = .center
    /// The compact set boxes use a small placeholder (the rep-range hint); form rows use the full value
    /// size so a "0" placeholder isn't tiny.
    var smallPlaceholder: Bool = true
    /// Called when editing ends (the field resigns focus). Lets a caller persist the value once per edit
    /// instead of on every keystroke, which keeps a single character from churning the whole screen.
    var onCommit: () -> Void = {}

    /// Returns a replacement translated to the right edge, or nil when UIKit's requested range already
    /// edits the existing suffix and can be applied normally. Kept pure so the right-only contract has a
    /// regression test independent of keyboard timing.
    static func trailingReplacement(
        in current: String,
        requestedRange range: NSRange,
        replacement string: String
    ) -> String? {
        let value = current as NSString
        let length = value.length
        let safeLength = min(max(range.length, 0), length)
        let requestedEnd = min(max(range.location + safeLength, 0), length)
        guard requestedEnd != length else { return nil }

        let trailingRange = NSRange(location: length - safeLength, length: safeLength)
        return value.replacingCharacters(in: trailingRange, with: string)
    }

    private static func valueFont() -> UIFont {
        // Matches `.forgeValue`: rounded, monospaced digits, at the body text size, scaled for Dynamic
        // Type (with adjustsFontForContentSizeCategory the field keeps up with the current size).
        var font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular)
        if let descriptor = font.fontDescriptor.withDesign(.rounded) {
            font = UIFont(descriptor: descriptor, size: 17)
        }
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: font)
    }

    func makeUIView(context: Context) -> UITextField {
        HangMonitor.note(.numberFieldMakeBegin)
        let field = PaddedTextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        field.textAlignment = alignment
        field.font = Self.valueFont()
        field.adjustsFontForContentSizeCategory = true
        field.adjustsFontSizeToFitWidth = true
        field.minimumFontSize = 13
        field.textColor = .label
        field.tintColor = .label
        field.accessibilityLabel = accessibilityLabel
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        HangMonitor.note(.numberFieldMakeEnd)
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
        if field.isFirstResponder { HangMonitor.note(.numberFieldFocusedUpdateBegin) }
        context.coordinator.parent = self
        let visibleText = field.isFirstResponder ? text : (displayText ?? text)
        if field.text != visibleText { field.text = visibleText }
        if field.keyboardType != keyboardType { field.keyboardType = keyboardType }
        if field.accessibilityLabel != accessibilityLabel { field.accessibilityLabel = accessibilityLabel }

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
        if field.isFirstResponder { HangMonitor.note(.numberFieldFocusedUpdateEnd) }
    }

    /// Resigns before the field goes away.
    ///
    /// A UITextField removed from the window while it is still first responder leaves UIKit holding a
    /// keyboard with nothing behind it: it stays up, its frame is recalculated over and over, and taps
    /// land nowhere. SwiftUI tears a representable down whenever the row's identity changes, so this is
    /// the backstop for any identity churn that is left.
    static func dismantleUIView(_ field: UITextField, coordinator: Coordinator) {
        HangMonitor.note(.numberFieldDismantleBegin)
        if field.isFirstResponder {
            HangMonitor.note(.numberFieldDismantleResignBegin)
            field.resignFirstResponder()
            HangMonitor.note(.numberFieldDismantleResignEnd)
        }
        HangMonitor.note(.numberFieldDismantleEnd)
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
            HangMonitor.note(.numberFieldEditingChangedBegin)
            parent.text = field.text ?? ""
            moveCaretToEnd(field)
            HangMonitor.note(.numberFieldEditingChangedEnd)
        }

        func textFieldDidBeginEditing(_ field: UITextField) {
            HangMonitor.note(.numberFieldDidBeginEditingBegin)
            HangMonitor.note(.valueFieldFocused)
            // Replace the rounded idle representation with the complete editable value.
            if field.text != parent.text { field.text = parent.text }
            moveCaretToEnd(field)
            HangMonitor.note(.numberFieldDidBeginEditingEnd)
        }

        func textFieldDidEndEditing(_ field: UITextField) {
            HangMonitor.note(.numberFieldDidEndEditingBegin)
            HangMonitor.note(.valueFieldEndedEditing)
            parent.text = field.text ?? ""
            parent.onCommit()
            field.text = parent.displayText ?? parent.text
            HangMonitor.note(.valueFieldCommitFinished)
            HangMonitor.note(.numberFieldDidEndEditingEnd)
        }

        /// Enforce trailing-edge editing even if UIKit establishes a middle selection through a hardware
        /// keyboard, accessibility command, or selection gesture. Changes that do not touch the existing
        /// suffix are translated to an equal-length range at the right edge. Normal end edits stay on
        /// UIKit's native path.
        func textField(
            _ field: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let current = field.text ?? ""
            guard let replacement = RightAlignedNumberField.trailingReplacement(
                in: current,
                requestedRange: range,
                replacement: string
            ) else { return true }

            field.text = replacement
            field.sendActions(for: .editingChanged)
            return false
        }

        /// Keeps the caret at the end, so a value is edited from the right like a calculator.
        ///
        /// Driven only by our own edits: focus arriving, and text changing. A touch is resolved to the
        /// end by `PaddedTextField`, and the delegate translates any non-touch middle edit to the suffix.
        /// This used to hook
        /// `textFieldDidChangeSelection`, which observes UIKit's selection changes and moved the caret
        /// back in response to them. The re-entrancy guard there only covered a synchronous callback,
        /// and UIKit re-establishes selection on a later turn of the run loop, by which time the guard
        /// was down again. The two could then trade selection changes without end and wedge the main
        /// thread, which is what a recorded freeze looks like: the keyboard resigning, a value
        /// committing, and then nothing.
        private func moveCaretToEnd(_ field: UITextField) {
            let end = field.endOfDocument
            guard let range = field.textRange(from: end, to: end), field.selectedTextRange != range else { return }
            field.selectedTextRange = range
        }
    }
}

/// A number box that keeps what you typed while you are typing it.
///
/// Binding a field straight at a formatted number cannot accept a decimal separator. Type "12," and the
/// value round-trips through the formatter, comes back as "12", and `updateUIView` deletes the separator
/// from under you, so a decimal can never be entered. The raw text lives here instead and reaches the
/// model when editing ends, which is how the set rows in a live workout already behave.
struct DecimalNumberField: View {
    /// The value in the unit on screen. Zero shows as an empty box.
    let value: Double
    var placeholder: String = "0"
    var width: CGFloat = 90
    /// Called when the field loses focus, with the parsed value. Zero means cleared.
    let onCommit: (Double) -> Void

    @State private var text = ""

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        formatter.minimum = 0
        return formatter
    }()

    private var formatted: String {
        value > 0 ? (Self.formatter.string(from: NSNumber(value: value)) ?? "") : ""
    }

    /// Accepts either separator: the decimal pad shows whichever the locale uses, and a number typed on
    /// one device should still read on another.
    private func parse(_ raw: String) -> Double {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return 0 }
        if let number = Self.formatter.number(from: trimmed) { return number.doubleValue }
        return Double(trimmed.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var body: some View {
        RightAlignedNumberField(
            text: $text,
            placeholder: placeholder,
            keyboardType: .decimalPad,
            alignment: .right,
            smallPlaceholder: false,
            onCommit: { onCommit(parse(text)) }
        )
        .frame(width: width, height: 28)
        .onAppear { text = formatted }
        // Follows the model when it moves for another reason, such as the weight unit changing.
        .onChange(of: value) { _, _ in text = formatted }
    }
}
