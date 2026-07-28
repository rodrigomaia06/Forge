//
//  RestTimerLiveActivity.swift
//  RestTimerWidget
//
//  The rest-timer Live Activity: Lock Screen banner and Dynamic Island. The countdown is driven by
//  the start/end dates in the shared ContentState, so the system updates the numbers itself.
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
            lockScreen(context)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.exerciseName ?? "Rest")
                    } icon: {
                        Image(systemName: "timer")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                        .font(.title2.monospacedDigit())
                        .frame(maxWidth: 68)
                        .multilineTextAlignment(.trailing)
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
            } compactTrailing: {
                Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                    .font(.caption2.monospacedDigit())
                    .frame(maxWidth: 40)
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }

    @ViewBuilder
    private func lockScreen(_ context: ActivityViewContext<RestTimerAttributes>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rest").font(.headline)
                if let name = context.attributes.exerciseName {
                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                .font(.system(size: 34, weight: .semibold).monospacedDigit())
                .frame(maxWidth: 120)
                .multilineTextAlignment(.trailing)
        }
    }
}
