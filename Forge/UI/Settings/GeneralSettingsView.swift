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
        Section {
            Picker("Weight Unit", selection: $settingsStore.weightUnit) {
                ForEach(WeightUnit.allCases, id: \.self) { weightUnit in
                    Text(weightUnit.title).tag(weightUnit)
                }
            }
        }
    }

    private var selectedAccent: ForgeAccent {
        ForgeAccent(rawValue: settingsStore.accentIdentifier) ?? .graphite
    }

    private var appearanceSection: some View {
        Section(
            header: Text("Accent color"),
            footer: Text("Tints buttons, links, and the selected tab. Graphite is the default monochrome look.")
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: Theme.Spacing.s)], spacing: Theme.Spacing.s) {
                ForEach(ForgeAccent.allCases) { accent in
                    let isSelected = accent == selectedAccent
                    Button {
                        Haptics.selection()
                        settingsStore.accentIdentifier = accent.rawValue
                    } label: {
                        Circle()
                            .fill(accent.color)
                            .frame(width: 30, height: 30)
                            // Hairline so the monochrome graphite swatch stays visible on any surface.
                            .overlay(Circle().strokeBorder(Color.forgeSeparator, lineWidth: accent == .graphite ? 1 : 0))
                            .padding(5)
                            .overlay(Circle().strokeBorder(isSelected ? Color.forgeLabel : .clear, lineWidth: 2))
                            .frame(minHeight: Theme.Layout.minTapTarget)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accent.title)
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
    }
    
    private var restTimerTimesSection: some View {
        Section(footer: Text("Used for exercises without their own rest time. Set a rest time per exercise on the exercise's page.")) {
            Picker("Default Rest Time", selection: $settingsStore.defaultRestTime) {
                ForEach(restTimerCustomTimes, id: \.self) { time in
                    Text(restTimerDurationFormatter.string(from: time) ?? "").tag(time)
                }
            }
        }
    }

    private var calendarSection: some View {
        Section {
            Picker("First Day of Week", selection: $settingsStore.firstWeekday) {
                Text("Sunday").tag(1)
                Text("Monday").tag(2)
            }
        }
    }
    
    private var restTimerSection: some View {
        Section(footer: Text("Keep the rest timer running even after it has elapsed. The time exceeded is displayed in red.")) {
            Toggle("Keep Rest Timer Running", isOn: Binding(get: {
                settingsStore.keepRestTimerRunning
            }, set: { newValue in
                settingsStore.keepRestTimerRunning = newValue
                
                // TODO in future somehow let RestTimerStore subscribe to this specific change
                RestTimerStore.shared.notifyKeepRestTimerRunningChanged()
            }))
        }
    }
    
    private var reminderSection: some View {
        Section(footer: Text("Sends a single reminder if you leave a workout in progress after logging a set.")) {
            Toggle("Unfinished workout reminder", isOn: $settingsStore.unfinishedWorkoutReminderEnabled)
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
        Section(footer: Text("Optional features. The trophy marks a set that is your best estimated one-rep max for that exercise. RPE is a rating of perceived exertion you can log per set.")) {
            Toggle("Personal record trophies", isOn: $settingsStore.showPersonalRecords)
            Toggle("RPE (perceived exertion)", isOn: $settingsStore.showRPE)
        }
    }

    var body: some View {
        Form {
            appearanceSection
            weightPickerSection
            calendarSection
            restTimerTimesSection
            restTimerSection
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
