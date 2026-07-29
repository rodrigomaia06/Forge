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
        Section(header: Text("Units")) {
            Picker("Weight unit", selection: $settingsStore.weightUnit) {
                ForEach(WeightUnit.allCases, id: \.self) { weightUnit in
                    Text(weightUnit.title).tag(weightUnit)
                }
            }
        }
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

    private var restTimerSection: some View {
        Section(header: Text("Rest timer"), footer: Text("The default is used for exercises without their own rest time (set that on the exercise's page). Keeping the timer running shows the time exceeded in red.")) {
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

    private var restTimerAlertSection: some View {
        Section(header: Text("Rest timer alert"), footer: Text("Plays when the rest timer ends. The sound also plays with the notification when Forge is in the background.")) {
            Toggle("Sound", isOn: $settingsStore.restTimerSound)
                .tint(.forgeSuccess)
            Toggle("Haptic", isOn: $settingsStore.restTimerHaptic)
                .tint(.forgeSuccess)
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

    var body: some View {
        Form {
            appearanceSection
            weightPickerSection
            calendarSection
            restTimerSection
            restTimerAlertSection
            reminderSection
            recordsSection
        }
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
