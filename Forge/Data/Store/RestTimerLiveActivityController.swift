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
    /// Fires at the end of the rest to push the overrun. Only touched on `queue`.
    private var overrunTask: Task<Void, Never>?

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
        guard let start = start, let endDate = end else {
            self.end()
            return
        }

        let isOverrun = endDate <= Date()
        let state = RestTimerAttributes.ContentState(startDate: start, endDate: endDate, isOverrun: isOverrun)
        // Stale at the end as a backstop, for when the app is suspended and cannot push anything. On its
        // own it arrived late: the system re-renders a stale activity on its own schedule, so the switch
        // to counting up in red could take a while to appear. The push below is what makes it prompt.
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

        if isOverrun {
            overrunTask?.cancel()
            overrunTask = nil
        } else {
            scheduleOverrun(start: start, endDate: endDate)
        }
    }

    /// Pushes the overrun the moment the rest ends, so the count flips to red without waiting on the
    /// system to notice the content has gone stale. Replaced whenever the timer changes, and cancelled
    /// when it stops, so only the current rest is ever waiting.
    private func scheduleOverrun(start: Date, endDate: Date) {
        overrunTask?.cancel()
        overrunTask = Task { [weak self] in
            let delay = endDate.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            self?.queue.async { self?.pushOverrun(start: start, endDate: endDate) }
        }
    }

    private func pushOverrun(start: Date, endDate: Date) {
        guard let activity = activity else { return }
        let state = RestTimerAttributes.ContentState(startDate: start, endDate: endDate, isOverrun: true)
        Task { await activity.update(ActivityContent(state: state, staleDate: endDate)) }
    }

    private func end() {
        overrunTask?.cancel()
        overrunTask = nil
        activity = nil
        for activity in Activity<RestTimerAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
