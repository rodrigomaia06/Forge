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
    @EnvironmentObject var settingsStore: SettingsStore
    
    @ObservedObject var workout: Workout

    /// The workout's start and end are editable (by tapping the stopwatch) only in edit mode, so a stray
    /// tap can't change the recorded times while logging.
    var isEditing: Bool = false

    // This view owns the refresher. `@ObservedObject = Refresher()` created a new publisher whenever
    // CurrentWorkoutView rebuilt its header, including while SwiftUI was already reconciling a timer-
    // driven update. Keep one object for this banner's identity instead.
    @StateObject private var refresher = Refresher()

    // Building an autoconnected publisher in body replaced the subscription on every tick: the tick
    // refreshed the view, whose new body created another publisher. One process-wide clock is enough for
    // the single live-workout banner and stays stable across parent renders.
    private static let refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    @State private var activeSheet: SheetType?
    @State private var showEditHint = false

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
        // Plain button so the navigation bar gives it the native Liquid Glass treatment; wrapping it in a
        // manual capsule made it read flat instead of glassy.
        Button("Close") {
            self.activeSheet = nil
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
        // The timer content is compact, so open at a shorter height than medium. Still draggable taller.
        .presentationDetents([.height(400), .large])
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
            // Both time readouts sit on the right, where iOS puts time and status. The stopwatch leads
            // the rest timer, keeping the order they have always been read in. An earlier attempt at
            // this put the rest timer on the left instead and was reverted; nothing moves to the left
            // here, the pair just moves across together.
            if showEditHint {
                Text("Editable in Edit mode")
                    .font(.caption2)
                    .foregroundColor(.forgeSecondaryLabel)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            Spacer()

            // In edit mode the stopwatch opens the start/end editor; otherwise a tap shows a brief hint
            // that the times can only be changed in edit mode.
            Button(action: {
                if isEditing {
                    self.activeSheet = .editTime
                } else {
                    Haptics.impact(.light)
                    withAnimation { showEditHint = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showEditHint = false }
                    }
                }
            }) {
                stopwatchLabel
            }
            .buttonStyle(.plain)

            // Rest timer, unless it has been turned off in Settings.
            if settingsStore.showRestTimer {
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
        .onReceive(Self.refreshTimer) { _ in self.refresher.refresh() }
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
