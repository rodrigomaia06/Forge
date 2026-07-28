//
//  RestTimerLiveActivityController.swift
//  Forge
//
//  Bridges the rest timer to a Live Activity (Dynamic Island + Lock Screen). Updates are local
//  (pushType: nil); the widget counts down on its own from the start/end dates, so this only starts,
//  retargets, or ends the activity when the timer changes.
//

import Foundation
import ActivityKit
import os.log

final class RestTimerLiveActivityController {
    static let shared = RestTimerLiveActivityController()
    private init() {}

    private var activity: Activity<RestTimerAttributes>?

    /// Match the Live Activity to the current rest timer. Ends it when there is no active timer.
    func sync(start: Date?, end: Date?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            stop()
            return
        }
        guard let start = start, let end = end, end > Date() else {
            stop()
            return
        }

        let state = RestTimerAttributes.ContentState(startDate: start, endDate: end)
        // Stay valid a little past the end so a just-finished timer still reads 0 rather than vanishing.
        let content = ActivityContent(state: state, staleDate: end.addingTimeInterval(60))

        if let activity = activity {
            Task { await activity.update(content) }
        } else {
            do {
                activity = try Activity.request(
                    attributes: RestTimerAttributes(),
                    content: content,
                    pushType: nil
                )
            } catch {
                os_log("Could not start rest-timer Live Activity: %{public}@", type: .error, error.localizedDescription)
            }
        }
    }

    func stop() {
        activity = nil
        for activity in Activity<RestTimerAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
