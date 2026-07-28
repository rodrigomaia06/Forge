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

    /// Selected accent theme. Stored by identifier; defaults to graphite (the monochrome look).
    var accentIdentifier: String {
        get {
            userDefaults.accentIdentifier
        }
        set {
            self.objectWillChange.send()
            userDefaults.accentIdentifier = newValue
        }
    }

    /// Per-exercise rest time override (nil = use the default rest time).
    func restTime(forExercise uuid: UUID) -> TimeInterval? {
        userDefaults.exerciseRestTimes[uuid.uuidString]
    }

    func setRestTime(_ time: TimeInterval?, forExercise uuid: UUID) {
        self.objectWillChange.send()
        var times = userDefaults.exerciseRestTimes
        times[uuid.uuidString] = time
        userDefaults.exerciseRestTimes = times
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
