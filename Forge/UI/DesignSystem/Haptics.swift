//
//  Haptics.swift
//  Forge
//
//  Subtle, purposeful haptics — used sparingly for confirmations and selection, never
//  gratuitously. Prefer these over ad-hoc UIFeedbackGenerator calls so the feel is consistent.
//

import UIKit

enum Haptics {
    /// Light tick for moving between options (tab changes, pickers).
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// A physical tap for a discrete action (e.g. completing a set).
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// Confirms a meaningful success (finishing a workout, a completed import).
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Signals a destructive or failed action.
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Signals a blocked action (e.g. trying to complete a set with no weight or reps).
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
