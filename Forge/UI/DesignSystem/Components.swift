//
//  Components.swift
//  Forge
//
//  Small reusable building blocks that read from the design tokens (Theme.swift), so the
//  same card and button treatment is defined once instead of inline at each call site.
//

import SwiftUI

/// The same one-physical-pixel separator used by a native List. Explicit cards use this instead of a
/// default Divider, whose proposed thickness can differ when it is hosted by a plain VStack.
struct ForgeListSeparator: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(Color(uiColor: .separator))
            .frame(height: 1 / displayScale)
            .accessibilityHidden(true)
    }
}

/// Filled accent button for a screen's primary action (e.g. "Start workout").
struct ForgePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.forgeHeadline)
            .foregroundColor(.forgeBackground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.Layout.minTapTarget)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .fill(Color.forgeAccent)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(Rectangle())
    }
}

extension View {
    /// The standard raised-surface card: a filled, rounded background used by tiles and rows.
    func forgeCard(radius: CGFloat = Theme.Radius.large) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.forgeSurface)
        )
    }
}

/// A text field with a clear (x) button that appears while it has content. Commits on end-edit and
/// when cleared, so callers can persist through the same closure.
struct ClearableTextField: View {
    let titleKey: String
    @Binding var text: String
    var onCommit: () -> Void = {}

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            TextField(titleKey, text: $text, onEditingChanged: { isEditing in
                if !isEditing { onCommit() }
            })
            if !text.isEmpty {
                Button {
                    text = ""
                    onCommit()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.forgeSecondaryLabel)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }
        }
    }
}
