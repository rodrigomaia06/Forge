//
//  RestTimerLiveActivity.swift
//  RestTimerWidget
//
//  The rest-timer Live Activity: Lock Screen banner and Dynamic Island, just the countdown. The
//  numbers are driven by the shared start/end dates, so the system updates them itself.
//
//  Past the rest time the count turns red, matching what the app shows once the timer is exceeded.
//  A widget cannot change its own colour at a future instant, so the staleness date is set to the end
//  of the rest and `context.isStale` is what flips it: the system marks the content stale exactly then.
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

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // Lock Screen / banner
            HStack(spacing: 12) {
                Label("Rest", systemImage: "timer")
                    .font(.title2.weight(.semibold))
                Spacer()
                Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                    .font(.system(size: 42, weight: .semibold).monospacedDigit())
                    .frame(maxWidth: 150)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(context.isStale ? Color.red : Color.white)
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
                            .foregroundStyle(.secondary)
                        Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                            .font(.largeTitle.monospacedDigit())
                            .multilineTextAlignment(.center)
                            .foregroundStyle(context.isStale ? Color.red : Color.white)
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
                // A fixed width (not maxWidth) keeps the countdown from collapsing to nothing in the
                // compact region, while still fitting up to "59:59".
                Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                    .monospacedDigit()
                    .foregroundStyle(context.isStale ? Color.red : Color.white)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 48)
            } minimal: {
                Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                    .monospacedDigit()
                    .foregroundStyle(context.isStale ? Color.red : Color.white)
                    .frame(width: 32)
            }
        }
    }
}
