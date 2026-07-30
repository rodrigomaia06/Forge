//
//  TimerBannerView.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 14.08.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import WorkoutDataKit

struct TimerBannerView: View {
    @EnvironmentObject var restTimerStore: RestTimerStore
    
    @ObservedObject var workout: Workout

    /// The workout's start and end are editable (by tapping the stopwatch) only in edit mode, so a stray
    /// tap can't change the recorded times while logging.
    var isEditing: Bool = false

    @ObservedObject private var refresher = Refresher()
    
    @State private var activeSheet: SheetType?

    private enum SheetType: Identifiable {
        case restTimer
        case editTime
        
        var id: Self { self }
    }

    private let workoutTimerDurationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    private var closeSheetButton: some View {
        Button {
            self.activeSheet = nil
        } label: {
            Text("Close")
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.xs)
                .forgeGlassCapsule()
        }
    }
    
    private var editTimeSheet: some View {
        NavigationStack {
            EditCurrentWorkoutTimeView(workout: workout)
                .navigationBarTitle("Workout duration", displayMode: .inline)
                .navigationBarItems(leading: closeSheetButton)
        }
        .presentationDetents([.medium])
    }

    private var restTimerSheet: some View {
        NavigationStack {
            RestTimerView().environmentObject(self.restTimerStore)
                .navigationBarTitle("Rest timer", displayMode: .inline)
                .navigationBarItems(leading: closeSheetButton)
        }
        // A compact sheet, not a full screen. Allow expanding for the running-timer view.
        .presentationDetents([.medium, .large])
    }
    
    private var stopwatchLabel: some View {
        HStack {
            Image(systemName: "clock")
            Text(workoutTimerDurationFormatter.string(from: workout.safeDuration) ?? "")
                .font(Font.body.monospacedDigit())
        }
        .padding()
    }

    var body: some View {
        HStack {
            // The stopwatch opens the start/end editor only in edit mode; otherwise it is a plain display.
            if isEditing {
                Button(action: { self.activeSheet = .editTime }) { stopwatchLabel }
            } else {
                stopwatchLabel.foregroundColor(.forgeSecondaryLabel)
            }

            Spacer()

            Button(action: {
                self.activeSheet = .restTimer
            }) {
                let remainingTime = restTimerStore.restTimerRemainingTime
                HStack {
                    Image(systemName: "timer")
                    if let remainingTime = remainingTime {
                        Text(restTimerDurationFormatter.string(from: abs(remainingTime.rounded(.up))) ?? "")
                            .font(Font.body.monospacedDigit())
                    }
                }
                .foregroundColor(remainingTime ?? 0 < 0 ? .forgeDestructive : nil)
                .padding()
            }
        }
        // No fill: the timer row sits on the workout canvas so it reads as part of the header rather
        // than a separate colored band.
        .sheet(item: $activeSheet) { sheet in
            if sheet == .editTime {
                self.editTimeSheet
            } else if sheet == .restTimer {
                self.restTimerSheet
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in self.refresher.refresh() }
    }
}

#if DEBUG
struct TimerBannerView_Previews: PreviewProvider {
    static var previews: some View {
        if RestTimerStore.shared.restTimerRemainingTime == nil {
            RestTimerStore.shared.restTimerStart = Date()
            RestTimerStore.shared.restTimerDuration = 10
        }
        return TimerBannerView(workout: MockWorkoutData.metricRandom.currentWorkout)
            .mockEnvironment(weightUnit: .metric)
    }
}
#endif
