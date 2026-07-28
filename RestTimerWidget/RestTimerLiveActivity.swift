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
                // The .timer text style is built to auto-size a countdown in the Island; timerInterval
                // reserved too much and clipped to "1:...".
                Text(context.state.endDate, style: .timer)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.white)
            }
        }
    }
}
