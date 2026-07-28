//
//  RestTimerLiveActivity.swift
//  RestTimerWidget
//
//  The rest-timer Live Activity: Lock Screen banner and Dynamic Island, just the countdown. The
//  numbers are driven by the shared start/end dates, so the system updates them itself.
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
                    .font(.headline)
                Spacer()
                Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                    .font(.system(size: 34, weight: .semibold).monospacedDigit())
                    .frame(maxWidth: 120)
                    .multilineTextAlignment(.trailing)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.6))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundStyle(.secondary)
                        Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                            .font(.title.monospacedDigit())
                            .multilineTextAlignment(.center)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(timerInterval: context.state.startDate...context.state.endDate, countsDown: true) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .tint(.white)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.white)
            } compactTrailing: {
                // No fixed frame: the island reserves the right width for the timer itself; a fixed
                // width was clipping it to "1:...". Scale down as a safety instead of truncating.
                Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.white)
            }
        }
    }
}
