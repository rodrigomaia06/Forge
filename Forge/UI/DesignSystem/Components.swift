//
//  Components.swift
//  Forge
//
//  Small reusable building blocks that read from the design tokens (Theme.swift), so the
//  same card and button treatment is defined once instead of inline at each call site.
//

import SwiftUI

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

/// Full-width Liquid Glass capsule for a prominent action (e.g. "Finish workout"). Uses the glass
/// treatment on iOS 26 and a system material capsule below it.
struct ForgeGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.forgeHeadline)
            .foregroundColor(.forgeLabel)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.Layout.minTapTarget)
            .forgeGlassCapsule()
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(Capsule())
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
