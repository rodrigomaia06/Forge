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
        // Stale exactly at the end. The activity stays on screen; the widget reads `isStale` to show the
        // overrun in red, the same way the app does once the rest time is exceeded. A widget cannot change
        // its own colour at a future instant, and this is the one signal the system flips for it.
        let content = ActivityContent(state: state, staleDate: endDate)

        // Adopt an activity this process did not start. `activity` is only set when we create one, so
        // after a relaunch it is nil while a Live Activity from the previous session is still running.
        // Without this, changing the rest time started a second activity instead of updating the one on
        // screen, so the adjustment appeared not to apply.
        if activity == nil {
            activity = Activity<RestTimerAttributes>.activities.first
        }

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
