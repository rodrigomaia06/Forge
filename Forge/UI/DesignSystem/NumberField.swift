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
        let field = PaddedTextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        // Both the placeholder and the entered value are centered in the box.
        field.textAlignment = .center
        field.font = Self.valueFont()
        field.adjustsFontForContentSizeCategory = true
        field.textColor = .label
        field.tintColor = .label
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        // The placeholder (a planned rep range like "8-12") is smaller than the value so it fits the
        // narrow box and reads as a hint rather than an entered number.
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .footnote),
                .foregroundColor: UIColor.secondaryLabel,
            ]
        )
        field.keyboardType = keyboardType
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: RightAlignedNumberField
        init(_ parent: RightAlignedNumberField) { self.parent = parent }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        /// Keep the caret at the end so the value is always edited from the right, never mid-number.
        func textFieldDidChangeSelection(_ field: UITextField) {
            let end = field.endOfDocument
            if let range = field.textRange(from: end, to: end), field.selectedTextRange != range {
                field.selectedTextRange = range
            }
        }
    }
}
