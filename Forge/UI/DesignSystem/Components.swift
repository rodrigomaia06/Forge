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

extension View {
    /// The standard raised-surface card: a filled, rounded background used by tiles and rows.
    func forgeCard(radius: CGFloat = Theme.Radius.large) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.forgeSurface)
        )
    }
}
