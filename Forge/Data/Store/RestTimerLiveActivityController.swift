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

    /// Every call into ActivityKit here crosses to a system daemon: `ActivityAuthorizationInfo()`,
    /// `Activity.request`, and enumerating `Activity.activities` all block until it answers. The
    /// caller is `RestTimerStore`'s setter, which runs on the main thread inside the tap that
    /// completes a set, so doing this inline stalled the UI for as long as the daemon took. Serialised
    /// off the main thread instead: nothing here draws, and the widget counts down from the dates on
    /// its own, so it does not matter that the hand-off is a moment late.
    private let queue = DispatchQueue(label: "com.rodrigomaia.forge.rest-timer-live-activity")

    /// Only touched on `queue`.
    private var activity: Activity<RestTimerAttributes>?

    /// Match the Live Activity to the current rest timer. Ends it when there is no active timer.
    func sync(start: Date?, end: Date?) {
        queue.async { [self] in apply(start: start, end: end) }
    }

    func stop() {
        queue.async { [self] in end() }
    }

    // MARK: - On the queue

    private func apply(start: Date?, end: Date?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            self.end()
            return
        }
        guard let start = start, let endDate = end, endDate > Date() else {
            self.end()
            return
        }

        let state = RestTimerAttributes.ContentState(startDate: start, endDate: endDate)
        // Stay valid a little past the end so a just-finished timer still reads 0 rather than vanishing.
        let content = ActivityContent(state: state, staleDate: endDate.addingTimeInterval(60))

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

    private func end() {
        activity = nil
        for activity in Activity<RestTimerAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
