//
//  Theme.swift
//  Forge
//
//  Forge's design tokens: one small, semantic layer the whole UI reads from, so
//  light/dark, Dynamic Type, increased-contrast, and a future user-selectable accent
//  colour stay consistent everywhere. Prefer these tokens over hard-coded values.
//
//  Character: quiet, native, high-contrast, legible at a glance during a workout.
//  Values lean on system semantics so they are correct in every appearance by default;
//  refine the concrete numbers once we can see rendered screens.
//

import SwiftUI

enum Theme {
    /// 4-point spacing scale. Use these instead of literal paddings.
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    /// Corner radii for cards, controls, and sheets.
    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }

    enum Layout {
        /// Minimum comfortable one-handed tap target (Apple HIG).
        static let minTapTarget: CGFloat = 44
    }
}

// MARK: - Semantic colours

extension Color {
    /// Screen background (grouped).
    static let forgeBackground = Color(.systemGroupedBackground)
    /// Raised surfaces: cards, rows, sheets.
    static let forgeSurface = Color(.secondarySystemGroupedBackground)
    /// Primary text and numbers.
    static let forgeLabel = Color(.label)
    /// Secondary / supporting text.
    static let forgeSecondaryLabel = Color(.secondaryLabel)
    /// Hairlines and dividers.
    static let forgeSeparator = Color(.separator)

    /// The one accent colour that signals interactivity and the current action.
    /// Backed by the asset accent for now; becomes user-selectable with custom themes later.
    static let forgeAccent = Color.accentColor

    // Meaning, not decoration — pair with a label/icon, never colour alone.
    static let forgeSuccess = Color(.systemGreen)
    static let forgeWarning = Color(.systemOrange)
    static let forgeDestructive = Color(.systemRed)
}

// MARK: - Typography

extension Font {
    /// Large scannable numbers (weights, reps, timers). Rounded + monospaced digits
    /// so values don't shift width as they change. Scales with Dynamic Type.
    static var forgeMetric: Font { .system(.title2, design: .rounded).monospacedDigit() }

    /// Inline numeric values inside rows, aligned in columns.
    static var forgeValue: Font { .system(.body, design: .rounded).monospacedDigit() }

    /// Section titles / row headlines.
    static var forgeHeadline: Font { .headline }

    /// Supporting captions and secondary metadata.
    static var forgeCaption: Font { .subheadline }
}
