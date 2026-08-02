//
//  NumberField.swift
//  Forge
//
//  A native numeric entry field that keeps raw text while it is being edited. The whole box is the
//  tap target, and the placeholder (used for a planned rep range) shows inside it when it is empty.
//

import SwiftUI
import UIKit

struct RightAlignedNumberField: View {
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .decimalPad
    /// Centered in the compact set boxes; trailing in labeled form rows.
    var alignment: NSTextAlignment = .center
    /// The compact set boxes use a small placeholder (the rep-range hint); form rows use the full value
    /// size so a "0" placeholder isn't tiny.
    var smallPlaceholder: Bool = true
    /// Called when editing ends (the field resigns focus). Lets a caller persist the value once per edit
    /// instead of on every keystroke, which keeps a single character from churning the whole screen.
    var onCommit: () -> Void = {}

    @FocusState private var isFocused: Bool
    @State private var committedCurrentFocus = false

    private static func valueFont() -> Font {
        // Matches `.forgeValue`: rounded, monospaced digits, at the body text size, scaled for Dynamic
        // Type.
        var font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular)
        if let descriptor = font.fontDescriptor.withDesign(.rounded) {
            font = UIFont(descriptor: descriptor, size: 17)
        }
        return Font(UIFontMetrics(forTextStyle: .body).scaledFont(for: font))
    }

    private var textAlignment: TextAlignment {
        switch alignment {
        case .left, .natural, .justified: return .leading
        case .right: return .trailing
        default: return .center
        }
    }

    private func commitFocusIfNeeded() {
        guard !committedCurrentFocus else { return }
        committedCurrentFocus = true
        HangMonitor.note("value field ended editing")
        let commit = onCommit
        // Focus changes arrive from the text system. Persist on the next main-queue turn so a Core Data
        // publication cannot re-evaluate the List while the keyboard is still finishing responder
        // teardown.
        DispatchQueue.main.async {
            commit()
            HangMonitor.note("value field commit finished")
        }
    }

    var body: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder)
                .font(smallPlaceholder ? .footnote : Self.valueFont())
                .foregroundColor(.forgeSecondaryLabel)
        )
        .font(Self.valueFont())
        .foregroundColor(.forgeLabel)
        .tint(.forgeLabel)
        .keyboardType(keyboardType)
        .multilineTextAlignment(textAlignment)
        .padding(.horizontal, 8)
        .focused($isFocused)
        .onChange(of: isFocused) { wasFocused, focused in
            if focused {
                committedCurrentFocus = false
                HangMonitor.note("value field focused")
            } else if wasFocused {
                commitFocusIfNeeded()
            }
        }
        .onDisappear {
            // A mode change or row removal can take a focused field out of the tree without first
            // delivering a focus change. Keep the typed value, but defer persistence until SwiftUI has
            // finished removing the view so no model publication occurs during its update pass.
            guard isFocused, !committedCurrentFocus else { return }
            committedCurrentFocus = true
            let commit = onCommit
            HangMonitor.note("focused value field removed")
            DispatchQueue.main.async {
                HangMonitor.note("value field ended editing")
                commit()
                HangMonitor.note("value field commit finished")
            }
        }
    }
}

/*
 The field used to be a `UIViewRepresentable` wrapping `UITextField`, with its own `UIToolbar`
 `inputAccessoryView`. Its screens also supplied SwiftUI's `.keyboard` toolbar. A Core Data change
 could update the representable while UIKit was resigning it, and `textFieldDidEndEditing` synchronously
 wrote SwiftUI state and Core Data from inside that responder callback. Freeze logs consistently ended
 just after that callback and included duplicate keyboard-hide notifications.

 The native `TextField` above gives focus and toolbar ownership to one framework and delivers its focus
 change after responder teardown. Keep this history next to the control because reintroducing a UIKit
 wrapper here would also reintroduce the failing ownership boundary.
 */

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
