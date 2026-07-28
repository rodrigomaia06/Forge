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

/// Dynamic grey defined by (white, alpha) in light and dark. Dark-first: the dark values
/// give Forge its near-black, high-contrast, monochrome-premium canvas; light stays usable.
private func forgeGrey(light: (CGFloat, CGFloat), dark: (CGFloat, CGFloat)) -> Color {
    Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: dark.0, alpha: dark.1)
            : UIColor(white: light.0, alpha: light.1)
    })
}

extension Color {
    /// Screen canvas — near-black in dark, soft grey in light.
    static let forgeBackground = forgeGrey(light: (0.95, 1), dark: (0.045, 1))
    /// Raised surfaces: cards, rows, the tab bar.
    static let forgeSurface = forgeGrey(light: (1.0, 1), dark: (0.11, 1))
    /// Primary text and numbers.
    static let forgeLabel = forgeGrey(light: (0.11, 1), dark: (0.97, 1))
    /// Secondary / supporting text.
    static let forgeSecondaryLabel = forgeGrey(light: (0.11, 0.55), dark: (0.97, 0.55))
    /// Hairlines and dividers.
    static let forgeSeparator = forgeGrey(light: (0.0, 0.10), dark: (1.0, 0.12))

    /// The current accent — signals interactivity and the current action. Reads the
    /// user's choice (see ForgeAccent); defaults to the high-contrast monochrome graphite.
    static var forgeAccent: Color { ForgeAccent.current.color }

    // Meaning, not decoration — pair with a label/icon, never colour alone.
    static let forgeSuccess = Color(.systemGreen)
    static let forgeWarning = Color(.systemOrange)
    static let forgeDestructive = Color(.systemRed)
}

// MARK: - Accent theme

/// User-selectable accent. Graphite is the default monochrome look; the rest are system hues
/// picked to stay legible on Forge's near-black canvas and its light appearance. The selection
/// drives `Color.forgeAccent` and the app-wide `.tint`, so it recolours interactive elements
/// everywhere without per-view changes.
enum ForgeAccent: String, CaseIterable, Identifiable {
    case graphite, orange, red, green, blue, indigo, purple, teal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .graphite: return "Graphite"
        case .orange: return "Orange"
        case .red: return "Red"
        case .green: return "Green"
        case .blue: return "Blue"
        case .indigo: return "Indigo"
        case .purple: return "Purple"
        case .teal: return "Teal"
        }
    }

    var color: Color {
        switch self {
        case .graphite: return forgeGrey(light: (0.11, 1), dark: (0.98, 1))
        case .orange: return Color(.systemOrange)
        case .red: return Color(.systemRed)
        case .green: return Color(.systemGreen)
        case .blue: return Color(.systemBlue)
        case .indigo: return Color(.systemIndigo)
        case .purple: return Color(.systemPurple)
        case .teal: return Color(.systemTeal)
        }
    }

    /// The accent chosen in Settings (falls back to graphite).
    static var current: ForgeAccent {
        ForgeAccent(rawValue: SettingsStore.shared.accentIdentifier) ?? .graphite
    }
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

    /// Large, calm greeting / screen title (e.g. "Good afternoon").
    static var forgeGreeting: Font { .system(size: 30, weight: .semibold) }

    /// Small uppercase section label (e.g. "MARCH 2026", tracked wider by the caller).
    static var forgeSectionLabel: Font { .system(.caption, design: .default).weight(.semibold) }
}
