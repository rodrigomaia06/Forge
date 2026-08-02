//
//  RestTimerStore.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 12.08.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import Foundation
import Combine

// to be used in other places
let restTimerDurationFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .positional
    formatter.allowedUnits = [.minute, .second]
    formatter.zeroFormattingBehavior = .pad
    return formatter
}()

let restTimerCustomTimes: [TimeInterval] = {
    stride(from: 30 as TimeInterval, through: 10*60, by: 5).map { $0 }
}()

final class RestTimerStore: ObservableObject {
    static let shared = RestTimerStore() // singleton

    let objectWillChange = ObservableObjectPublisher()
    
    private var userDefaults: UserDefaults

    private var settingsCancellable: AnyCancellable?

    private init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        // restTimerRemainingTime depends on SettingsStore.keepRestTimerRunning. Forward that store's
        // changes so the timer reacts when the setting flips, instead of callers poking us manually.
        settingsCancellable = SettingsStore.shared.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
    }
    
    private convenience init() {
        self.init(userDefaults: UserDefaults.standard)
    }
    
    var restTimerStart: Date? {
        get {
            userDefaults.restTimerStart
        }
        set {
            HangMonitor.note("RestTimerStore.start setter begin")
            defer { HangMonitor.note("RestTimerStore.start setter end") }
            self.objectWillChange.send()
            userDefaults.restTimerStart = newValue
            updateNotification()
        }
    }
    
    var restTimerDuration: TimeInterval? {
        get {
            userDefaults.restTimerDuration
        }
        set {
            HangMonitor.note("RestTimerStore.duration setter begin")
            defer { HangMonitor.note("RestTimerStore.duration setter end") }
            self.objectWillChange.send()
            userDefaults.restTimerDuration = newValue
            updateNotification()
        }
    }
    
    var recentRestTimes: [TimeInterval] {
        get {
            userDefaults.recentRestTimes
        }
        set {
            self.objectWillChange.send()
            userDefaults.recentRestTimes = newValue
        }
    }
    
    /// Brings the Live Activity and the end-of-rest notification back in line with the timer, or takes
    /// them down when the rest timer is switched off.
    ///
    /// Switching it off hides the timer, it does not stop it. The start and the duration are left alone,
    /// so the rest is still running underneath and comes back where it should the moment it is switched
    /// on again. Only the two surfaces go: the activity above the camera, and the alert that would have
    /// fired.
    private func updateNotification() {
        HangMonitor.note("RestTimerStore.updateSurfaces begin")
        defer { HangMonitor.note("RestTimerStore.updateSurfaces end") }
        guard SettingsStore.shared.showRestTimer else {
            NotificationManager.shared.removePendingNotificationRequests(withIdentifiers: [.restTimerUp])
            NotificationManager.shared.removeDeliveredNotification(withIdentifiers: [.restTimerUp])
            RestTimerLiveActivityController.shared.stop()
            return
        }
        NotificationManager.shared.updateRestTimerUpNotificationRequest(remainingTime: self.restTimerRemainingTime, totalTime: self.restTimerDuration)
        RestTimerLiveActivityController.shared.sync(start: self.restTimerStart, end: self.restTimerEnd)
    }

    /// Re-applies the surfaces after the rest timer is switched on or off, so the change reaches a rest
    /// that is already running instead of waiting for the next one.
    func refreshSurfaces() {
        objectWillChange.send()
        updateNotification()
    }
}

extension RestTimerStore {
    var restTimerEnd: Date? {
        guard let duration = restTimerDuration else { return nil }
        return restTimerStart?.addingTimeInterval(duration)
    }
    
    var restTimerRemainingTime: TimeInterval? {
        guard let restTimerEnd = restTimerEnd else { return nil }
        let remainingTime = restTimerEnd.timeIntervalSince(Date())
        guard remainingTime >= 0 || SettingsStore.shared.keepRestTimerRunning else { return nil }
        return remainingTime
    }
}

extension RestTimerStore {
    func cancel() {
        restTimerStart = nil
        restTimerDuration = nil
    }
}
