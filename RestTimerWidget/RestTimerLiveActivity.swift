//
//  RestTimerLiveActivity.swift
//  RestTimerWidget
//
//  The rest-timer Live Activity: Lock Screen banner and Dynamic Island, just the countdown. The
//  numbers are driven by the shared start/end dates, so the system updates them itself.
//
//  Past the rest time the count keeps going, upwards and in red, the same as the app. A widget cannot
//  change itself at a future instant, so the content's staleness date is set to the end of the rest and
//  `context.isStale` is what flips it: the system marks the content stale exactly then.
//

import ActivityKit
import WidgetKit
import SwiftUI

@main
struct RestTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        RestTimerLiveActivity()
    }
}

/// The rest count, in whichever direction applies.
///
/// `Text(timerInterval:)` stops at the end of the range it is given, which is why it would otherwise
/// sit at 00:00 once the rest is up. The overrun is a second interval starting where the first one
/// ends, counted upwards, so it reads as how long the rest has been exceeded by.
private struct RestCount: View {
    let state: RestTimerAttributes.ContentState
    let isOverrun: Bool

    /// The counting-up range still needs an upper bound. An hour is far longer than a rest is ever
    /// left running over, and the activity ends well before then.
    private var overrunEnd: Date { state.endDate.addingTimeInterval(60 * 60) }

    var body: some View {
        if isOverrun {
            Text(timerInterval: state.endDate...overrunEnd, countsDown: false)
                .foregroundStyle(Color.red)
        } else {
            Text(timerInterval: state.startDate...state.endDate, countsDown: true)
                .foregroundStyle(Color.white)
        }
    }
}

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // Lock Screen / banner
            HStack(spacing: 12) {
                Label("Rest", systemImage: "timer")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(context.isStale ? Color.red : Color.white)
                Spacer()
                RestCount(state: context.state, isOverrun: context.isStale)
                    .font(.system(size: 42, weight: .semibold).monospacedDigit())
                    .frame(maxWidth: 150)
                    .multilineTextAlignment(.trailing)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.6))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                            .font(.title2)
                            .foregroundStyle(context.isStale ? Color.red : Color.secondary)
                        RestCount(state: context.state, isOverrun: context.isStale)
                            .font(.largeTitle.monospacedDigit())
                            .multilineTextAlignment(.center)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(timerInterval: context.state.startDate...context.state.endDate, countsDown: true) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .tint(context.isStale ? Color.red : Color.white)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(context.isStale ? Color.red : Color.white)
            } compactTrailing: {
                // A fixed width (not maxWidth) keeps the count from collapsing to nothing in the
                // compact region, while still fitting up to "59:59".
                RestCount(state: context.state, isOverrun: context.isStale)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 48)
            } minimal: {
                RestCount(state: context.state, isOverrun: context.isStale)
                    .monospacedDigit()
                    .frame(width: 32)
            }
        }
    }
}
