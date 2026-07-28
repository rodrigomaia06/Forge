//
//  UserDefaults+Settings.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 11.07.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import Foundation

extension UserDefaults {
    enum SettingsKeys: String, CaseIterable {
        case weightUnit
        case defaultRestTime
        case defaultRestTimeDumbbellBased
        case defaultRestTimeBarbellBased
        case keepRestTimerRunning
        case maxRepetitionsOneRepMax
        case autoBackup
        case firstWeekday
        case accentIdentifier
        case unfinishedWorkoutReminderEnabled
        case unfinishedWorkoutReminderDelay
    }

    /// Identifier of the selected accent theme (see ForgeAccent). Empty string means the default.
    var accentIdentifier: String {
        set { self.set(newValue, forKey: SettingsKeys.accentIdentifier.rawValue) }
        get { self.string(forKey: SettingsKeys.accentIdentifier.rawValue) ?? "" }
    }

    /// Whether to schedule one reminder after backgrounding a workout with completed sets.
    var unfinishedWorkoutReminderEnabled: Bool {
        set { self.set(newValue, forKey: SettingsKeys.unfinishedWorkoutReminderEnabled.rawValue) }
        get { self.value(forKey: SettingsKeys.unfinishedWorkoutReminderEnabled.rawValue) as? Bool ?? true }
    }

    /// Delay before the single unfinished-workout reminder fires (seconds). Default 15 minutes.
    var unfinishedWorkoutReminderDelay: TimeInterval {
        set { self.set(newValue, forKey: SettingsKeys.unfinishedWorkoutReminderDelay.rawValue) }
        get { self.value(forKey: SettingsKeys.unfinishedWorkoutReminderDelay.rawValue) as? TimeInterval ?? 15 * 60 }
    }

    var weightUnit: WeightUnit {
        set {
            self.set(newValue.rawValue, forKey: SettingsKeys.weightUnit.rawValue)
        }
        get {
            let weightUnit = WeightUnit(rawValue: self.string(forKey: SettingsKeys.weightUnit.rawValue) ?? "")
            if let weightUnit = weightUnit {
                return weightUnit
            } else {
                let fallback = Locale.current.usesMetricSystem ? WeightUnit.metric : WeightUnit.imperial
                self.weightUnit = fallback // safe the new weight unit
                return fallback
            }
        }
    }
    
    var defaultRestTime: TimeInterval {
        set {
            self.set(newValue, forKey: SettingsKeys.defaultRestTime.rawValue)
        }
        get {
            self.value(forKey: SettingsKeys.defaultRestTime.rawValue) as? TimeInterval ?? 90 // default 1:30
        }
    }
    
    var defaultRestTimeDumbbellBased: TimeInterval {
        set {
            self.set(newValue, forKey: SettingsKeys.defaultRestTimeDumbbellBased.rawValue)
        }
        get {
            self.value(forKey: SettingsKeys.defaultRestTimeDumbbellBased.rawValue) as? TimeInterval ?? 150 // default 2:30
        }
    }
    
    var defaultRestTimeBarbellBased: TimeInterval {
        set {
            self.set(newValue, forKey: SettingsKeys.defaultRestTimeBarbellBased.rawValue)
        }
        get {
            self.value(forKey: SettingsKeys.defaultRestTimeBarbellBased.rawValue) as? TimeInterval ?? 180 // default 3:00
        }
    }
    
    var keepRestTimerRunning: Bool {
        set {
            self.set(newValue, forKey: SettingsKeys.keepRestTimerRunning.rawValue)
        }
        get {
            self.value(forKey: SettingsKeys.keepRestTimerRunning.rawValue) as? Bool ?? true // default true
        }
    }
    
    var maxRepetitionsOneRepMax: Int {
        set {
            self.set(newValue, forKey: SettingsKeys.maxRepetitionsOneRepMax.rawValue)
        }
        get {
            (self.value(forKey: SettingsKeys.maxRepetitionsOneRepMax.rawValue) as? Int)?.clamped(to: maxRepetitionsOneRepMaxValues) ?? 5 // default 5
        }
    }
    
    var autoBackup: Bool {
        set {
            self.set(newValue, forKey: SettingsKeys.autoBackup.rawValue)
        }
        get {
            self.value(forKey: SettingsKeys.autoBackup.rawValue) as? Bool ?? false // default false
        }
    }
    
    /// Calendar first weekday: 1 = Sunday, 2 = Monday. Defaults to the locale's.
    var firstWeekday: Int {
        set {
            self.set(newValue, forKey: SettingsKeys.firstWeekday.rawValue)
        }
        get {
            (self.value(forKey: SettingsKeys.firstWeekday.rawValue) as? Int) ?? Calendar.current.firstWeekday
        }
    }
}

let maxRepetitionsOneRepMaxValues = 1...10
