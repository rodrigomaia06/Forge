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
    
    var body: some View {
        Form {
            weightPickerSection
            calendarSection
            restTimerTimesSection
            restTimerSection
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
