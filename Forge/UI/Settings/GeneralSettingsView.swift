//
//  GeneralSettingsView.swift
//  Iron
//
//  Created by Karim Abou Zeid on 31.10.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    
    private var weightPickerSection: some View {
        Section(header: Text("Weight"), footer: Text("Bodyweight weighs bodyweight exercises like pull-ups and dips in charts and totals. Log a per-set added or assisted amount for weighted or assisted reps. Leave it at 0 to count only the added weight.")) {
            Picker("Unit", selection: $settingsStore.weightUnit) {
                ForEach(WeightUnit.allCases, id: \.self) { weightUnit in
                    Text(weightUnit.title).tag(weightUnit)
                }
            }
            HStack {
                Text("Bodyweight")
                Spacer()
                HStack(spacing: 0) {
                    DecimalNumberField(value: displayedBodyweight, width: 60) { newValue in
                        settingsStore.bodyweight = newValue > 0
                            ? WeightUnit.convert(weight: newValue, from: settingsStore.weightUnit, to: .metric)
                            : 0
                    }
                    Text(settingsStore.weightUnit.unit.symbol)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    /// Bodyweight shown in the user's unit; stored as kilograms. Empty or 0 clears it.
    private var displayedBodyweight: Double {
        let kg = settingsStore.bodyweight
        guard kg > 0 else { return 0 }
        return WeightUnit.convert(weight: kg, from: .metric, to: settingsStore.weightUnit)
    }

    private var appearance: Binding<ForgeAppearance> {
        Binding(
            get: { ForgeAppearance(rawValue: settingsStore.appearance) ?? .dark },
            set: { settingsStore.appearance = $0.rawValue }
        )
    }

    private var appearanceSection: some View {
        Section(
            header: Text("Appearance"),
            footer: Text("Theme sets light or dark, or follows the system.")
        ) {
            Picker("Theme", selection: appearance) {
                ForEach(ForgeAppearance.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        }
    }

    private var calendarSection: some View {
        Section(header: Text("Calendar")) {
            Picker("First day of week", selection: $settingsStore.firstWeekday) {
                Text("Sunday").tag(1)
                Text("Monday").tag(2)
            }
        }
    }

    /// Everything below the switch depends on there being a rest timer at all, so it is all hidden when
    /// the timer is off rather than left as settings for something that never runs.
    private var restTimerSection: some View {
        Section(header: Text("Rest timer"), footer: Text(restTimerFooter)) {
            Toggle("Rest timer", isOn: $settingsStore.showRestTimer)
                .tint(.forgeSuccess)
            if settingsStore.showRestTimer {
                Picker("Default rest time", selection: $settingsStore.defaultRestTime) {
                    ForEach(restTimerCustomTimes, id: \.self) { time in
                        Text(restTimerDurationFormatter.string(from: time) ?? "").tag(time)
                    }
                }
                Toggle("Keep rest timer running", isOn: Binding(get: {
                    settingsStore.keepRestTimerRunning
                }, set: { newValue in
                    settingsStore.keepRestTimerRunning = newValue
                }))
                .tint(.forgeSuccess)
            }
        }
    }

    private var restTimerFooter: String {
        settingsStore.showRestTimer
            ? "The default is used for exercises without their own rest time (set that on the exercise's page). Keeping the timer running shows the time exceeded in red."
            : "Off, the timer is not shown during a workout, finishing a set does not start one, and no rest alert arrives."
    }

    @ViewBuilder private var restTimerAlertSection: some View {
        if settingsStore.showRestTimer {
            Section(header: Text("Rest timer alert"), footer: Text("Plays when the rest timer ends. The sound also plays with the notification when Forge is in the background.")) {
                Toggle("Sound", isOn: $settingsStore.restTimerSound)
                    .tint(.forgeSuccess)
                Toggle("Haptic", isOn: $settingsStore.restTimerHaptic)
                    .tint(.forgeSuccess)
            }
        }
    }
    
    private var reminderSection: some View {
        Section(header: Text("Reminders"), footer: Text("Sends a single reminder if you leave a workout in progress after logging a set.")) {
            Toggle("Unfinished workout reminder", isOn: $settingsStore.unfinishedWorkoutReminderEnabled)
                .tint(.forgeSuccess)
            if settingsStore.unfinishedWorkoutReminderEnabled {
                Picker("Remind after", selection: $settingsStore.unfinishedWorkoutReminderDelay) {
                    Text("15 minutes").tag(TimeInterval(15 * 60))
                    Text("30 minutes").tag(TimeInterval(30 * 60))
                    Text("1 hour").tag(TimeInterval(60 * 60))
                    Text("2 hours").tag(TimeInterval(120 * 60))
                }
            }
        }
    }

    private var recordsSection: some View {
        Section(header: Text("Extras"), footer: Text("Optional features. The trophy marks a set that is your best estimated one-rep max for that exercise. RPE is a rating of perceived exertion you can log per set.")) {
            Toggle("Personal record trophies", isOn: $settingsStore.showPersonalRecords)
                .tint(.forgeSuccess)
            Toggle("RPE (perceived exertion)", isOn: $settingsStore.showRPE)
                .tint(.forgeSuccess)
        }
    }

    private var workoutNameSection: some View {
        Section(header: Text("Workout name"), footer: Text("Name a workout started from a routine as \"Plan - Routine\", or just the routine name. Workouts you name yourself keep their name.")) {
            Toggle("Show plan in name", isOn: $settingsStore.showPlanInWorkoutTitle)
                .tint(.forgeSuccess)
        }
    }

    var body: some View {
        Form {
            appearanceSection
            weightPickerSection
            calendarSection
            restTimerSection
            restTimerAlertSection
            reminderSection
            workoutNameSection
            recordsSection
        }
        .keyboardDoneToolbar()
        .navigationBarTitle("General", displayMode: .inline)
    }
}

#if DEBUG
struct GeneralSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSettingsView()
            .mockEnvironment(weightUnit: .metric)
    }
}
#endif
