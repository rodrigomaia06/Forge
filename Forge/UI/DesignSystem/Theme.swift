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

    /// The accent that signals interactivity and the current action. A single high-contrast
    /// monochrome tint (near-white in dark, near-black in light) rather than a colour, so the app
    /// stays standard and quiet.
    static let forgeAccent = forgeGrey(light: (0.11, 1), dark: (0.98, 1))

    // Meaning, not decoration — pair with a label/icon, never colour alone.
    static let forgeSuccess = Color(.systemGreen)
    static let forgeWarning = Color(.systemOrange)
    static let forgeDestructive = Color(.systemRed)
}

/// Light, dark, or follow the system. Forge is dark-first, so dark is the default.
enum ForgeAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// The scheme to force on the app, or nil to follow the system setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
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

    /// Large, calm greeting / screen title (e.g. "Good afternoon"). Uses a text style so it
    /// scales with Dynamic Type instead of clipping at a fixed size.
    static var forgeGreeting: Font { .system(.largeTitle, design: .default).weight(.semibold) }

    /// Small uppercase section label (e.g. "MARCH 2026", tracked wider by the caller).
    static var forgeSectionLabel: Font { .system(.caption, design: .default).weight(.semibold) }
}
