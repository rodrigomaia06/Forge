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
        /// Whether the rest time has been passed, so the widget counts upwards in red.
        ///
        /// The app pushes this the moment the rest ends, because leaving it to the content's staleness
        /// date meant waiting on the system's own refresh schedule and the change arrived late. Staleness
        /// is still set, as a backstop for when the app is suspended and cannot push anything. Defaults
        /// to false so a state encoded before this existed still decodes.
        var isOverrun: Bool = false
    }
}
