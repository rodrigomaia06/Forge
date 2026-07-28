//
//  RestTimerActivity.swift
//  Forge
//
//  Shared between the app and the RestTimerWidget extension: the Live Activity's attributes and
//  its dynamic content. The countdown is driven by endDate, so the Lock Screen and Dynamic Island
//  update themselves via Text(timerInterval:) without the app pushing updates.
//

import Foundation
import ActivityKit

struct RestTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// When the current rest started (for a valid timer range and the progress ring).
        var startDate: Date
        /// When the rest timer reaches zero.
        var endDate: Date
    }

    /// The exercise the rest belongs to, if known.
    var exerciseName: String?
}
