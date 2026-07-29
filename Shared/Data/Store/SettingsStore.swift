//
//  SettingsStore.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 16.07.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

final class SettingsStore: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    
    private var userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    var weightUnit: WeightUnit {
        get {
            userDefaults.weightUnit
        }
        set {
            self.objectWillChange.send()
            userDefaults.weightUnit = newValue
        }
    }
    
    var defaultRestTime: TimeInterval {
        get {
            userDefaults.defaultRestTime
        }
        set {
            self.objectWillChange.send()
            userDefaults.defaultRestTime = newValue
        }
    }
    
    var defaultRestTimeDumbbellBased: TimeInterval {
        get {
            userDefaults.defaultRestTimeDumbbellBased
        }
        set {
            self.objectWillChange.send()
            userDefaults.defaultRestTimeDumbbellBased = newValue
        }
    }
    
    var defaultRestTimeBarbellBased: TimeInterval {
        get {
            userDefaults.defaultRestTimeBarbellBased
        }
        set {
            self.objectWillChange.send()
            userDefaults.defaultRestTimeBarbellBased = newValue
        }
    }
    
    var keepRestTimerRunning: Bool {
        get {
            userDefaults.keepRestTimerRunning
        }
        set {
            self.objectWillChange.send()
            userDefaults.keepRestTimerRunning = newValue
        }
    }

    var showPlanInWorkoutTitle: Bool {
        get {
            userDefaults.showPlanInWorkoutTitle
        }
        set {
            self.objectWillChange.send()
            userDefaults.showPlanInWorkoutTitle = newValue
        }
    }
    
    var maxRepetitionsOneRepMax: Int {
        get {
            userDefaults.maxRepetitionsOneRepMax
        }
        set {
            self.objectWillChange.send()
            userDefaults.maxRepetitionsOneRepMax = newValue
        }
    }
    
    var autoBackup: Bool {
        get {
            userDefaults.autoBackup
        }
        set {
            self.objectWillChange.send()
            userDefaults.autoBackup = newValue
        }
    }
    
    /// Calendar first weekday: 1 = Sunday, 2 = Monday.
    var firstWeekday: Int {
        get {
            userDefaults.firstWeekday
        }
        set {
            self.objectWillChange.send()
            userDefaults.firstWeekday = newValue
        }
    }

    var unfinishedWorkoutReminderEnabled: Bool {
        get {
            userDefaults.unfinishedWorkoutReminderEnabled
        }
        set {
            self.objectWillChange.send()
            userDefaults.unfinishedWorkoutReminderEnabled = newValue
        }
    }

    var unfinishedWorkoutReminderDelay: TimeInterval {
        get {
            userDefaults.unfinishedWorkoutReminderDelay
        }
        set {
            self.objectWillChange.send()
            userDefaults.unfinishedWorkoutReminderDelay = newValue
        }
    }

    var showPersonalRecords: Bool {
        get {
            userDefaults.showPersonalRecords
        }
        set {
            self.objectWillChange.send()
            userDefaults.showPersonalRecords = newValue
        }
    }

    var showRPE: Bool {
        get {
            userDefaults.showRPE
        }
        set {
            self.objectWillChange.send()
            userDefaults.showRPE = newValue
        }
    }

    var restTimerSound: Bool {
        get {
            userDefaults.restTimerSound
        }
        set {
            self.objectWillChange.send()
            userDefaults.restTimerSound = newValue
        }
    }

    var restTimerHaptic: Bool {
        get {
            userDefaults.restTimerHaptic
        }
        set {
            self.objectWillChange.send()
            userDefaults.restTimerHaptic = newValue
        }
    }

    /// App appearance preference: "system", "light", or "dark".
    var appearance: String {
        get {
            userDefaults.appearance
        }
        set {
            self.objectWillChange.send()
            userDefaults.appearance = newValue
        }
    }
}

#if DEBUG
extension SettingsStore {
    static let mockMetric: SettingsStore = {
        let store = SettingsStore(userDefaults: UserDefaults(suiteName: "mock_metric")!)
        store.weightUnit = .metric
        return store
    }()

    static let mockImperial: SettingsStore = {
        let store = SettingsStore(userDefaults: UserDefaults(suiteName: "mock_imperial")!)
        store.weightUnit = .imperial
        return store
    }()
}
#endif
