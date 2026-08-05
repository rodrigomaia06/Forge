//
//  NotificationManager.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 03.09.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import UserNotifications
import AudioToolbox
import Foundation

class NotificationManager: NSObject {
    static let shared = NotificationManager(notificationCenter: UNUserNotificationCenter.current())
    
    let notificationCenter: UNUserNotificationCenter
    
    init(notificationCenter: UNUserNotificationCenter) {
        self.notificationCenter = notificationCenter
        super.init()
        self.notificationCenter.delegate = self
        
        let restTimerAdd30Action = UNNotificationAction(identifier: NotificationActionIdentifier.restTimerAdd30.rawValue, title: "+30s")
        let restTimerAdd60Action = UNNotificationAction(identifier: NotificationActionIdentifier.restTimerAdd60.rawValue, title: "+60s")
        let restTimerAdd90Action = UNNotificationAction(identifier: NotificationActionIdentifier.restTimerAdd90.rawValue, title: "+90s")
        // Define the notification type
        let restTimerUpCategory =
            UNNotificationCategory(identifier: NotificationCategoryIdentifier.restTimerUp.rawValue,
                                   actions: [restTimerAdd30Action, restTimerAdd60Action, restTimerAdd90Action],
                                   intentIdentifiers: [],
                                   hiddenPreviewsBodyPlaceholder: "",
                                   options: [.hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle, .allowAnnouncement])
        // Register the notification type.
        notificationCenter.setNotificationCategories([restTimerUpCategory])
    }
    
    func requestAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
            if let error = error {
                print(error)
            }
        }
    }
    
    func removePendingNotificationRequests(withIdentifiers: [NotificationIdentifier]) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: withIdentifiers.map { $0.rawValue })
    }
    
    func removeDeliveredNotification(withIdentifiers: [NotificationIdentifier]) {
        notificationCenter.removeDeliveredNotifications(withIdentifiers: withIdentifiers.map { $0.rawValue })
    }

    func requestUnfinishedWorkoutNotification(after delay: TimeInterval) {
        notificationCenter.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

            let content = UNMutableNotificationContent()
            content.title = "Unfinished workout"
            content.body = "You have an unfinished workout. Do you want to finish it?"
            if settings.soundSetting == .enabled {
                content.sound = UNNotificationSound.default
            }

            // A single reminder, not a repeating one. The system requires a positive interval.
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, delay), repeats: false)

            let request = UNNotificationRequest(identifier: NotificationIdentifier.unfinishedWorkout.rawValue, content: content, trigger: trigger)
            
            self.notificationCenter.add(request) { (error) in
                if let error = error {
                    print("error \(String(describing: error))")
                }
            }
        }
    }
    
    func updateRestTimerUpNotificationRequest(remainingTime: TimeInterval?, totalTime: TimeInterval? = nil) {
        notificationCenter.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            
            guard let remainingTime = remainingTime, remainingTime > 0 else {
                self.removePendingNotificationRequests(withIdentifiers: [.restTimerUp])
                self.removeDeliveredNotification(withIdentifiers: [.restTimerUp])
                return
            }

            // Clear any earlier rest-timer banner still sitting in Notification Center so repeated rests
            // in one session replace the last alert instead of stacking up. The Live Activity in the
            // Dynamic Island carries the live countdown; this notification is only the end-of-rest alert.
            self.removeDeliveredNotification(withIdentifiers: [.restTimerUp])

            let content = UNMutableNotificationContent()
            content.title = "You've rested enough!"
            if let totalTime = totalTime, let totalTimeString = restTimerDurationFormatter.string(from: totalTime) {
                content.title += " (\(totalTimeString))"
            }
            content.body = "Back to work."
            if settings.soundSetting == .enabled, SettingsStore.shared.restTimerSound {
                content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm.wav"))
            }
            content.categoryIdentifier = NotificationCategoryIdentifier.restTimerUp.rawValue
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, remainingTime), repeats: false)
            
            let request = UNNotificationRequest(identifier: NotificationIdentifier.restTimerUp.rawValue, content: content, trigger: trigger)
            
            self.notificationCenter.add(request) { (error) in
                if let error = error {
                    print("error \(String(describing: error))")
                }
            }
        }
    }
    
    enum NotificationIdentifier: String {
        case unfinishedWorkout
        case restTimerUp
    }
    
    enum NotificationCategoryIdentifier: String {
        case restTimerUp
    }
    
    enum NotificationActionIdentifier: String {
        case restTimerAdd30
        case restTimerAdd60
        case restTimerAdd90
    }
}

extension NotificationManager {
    /// The bundled alarm.wav as a system sound, for playing in-app when the timer ends in the foreground.
    static let restAlarmSoundID: SystemSoundID = {
        var soundID: SystemSoundID = 0
        if let url = Bundle.main.url(forResource: "alarm", withExtension: "wav") {
            AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        }
        return soundID
    }()
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        guard notification.request.identifier == NotificationIdentifier.restTimerUp.rawValue else {
            completionHandler([])
            return
        }
        // The rest timer ended while Forge is in the foreground. Fire the configured haptic and play the
        // bundled alarm in-app; the notification carries no sound here so it does not double up.
        if SettingsStore.shared.restTimerHaptic {
            DispatchQueue.main.async { Haptics.success() }
        }
        if SettingsStore.shared.restTimerSound {
            DispatchQueue.main.async { AudioServicesPlaySystemSound(Self.restAlarmSoundID) }
        }
        completionHandler([.alert])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        guard let actionIdentifier = NotificationActionIdentifier(rawValue: response.actionIdentifier) else {
            completionHandler()
            return
        }

        DispatchQueue.main.async {
            defer { completionHandler() }
            guard let start = RestTimerStore.shared.restTimerStart,
                  let duration = RestTimerStore.shared.restTimerDuration else { return }

            switch actionIdentifier {
            case .restTimerAdd30:
                self.adjustRestTimer(start: start, duration: duration, delta: 30)
            case .restTimerAdd60:
                self.adjustRestTimer(start: start, duration: duration, delta: 60)
            case .restTimerAdd90:
                self.adjustRestTimer(start: start, duration: duration, delta: 90)
            }
        }
    }

    private func adjustRestTimer(start: Date, duration: TimeInterval, delta: TimeInterval) {
        guard let timer = RestTimerLogic.adjustedTimer(start: start, duration: duration, delta: delta) else {
            RestTimerStore.shared.cancel()
            return
        }
        RestTimerStore.shared.setTimer(start: timer.start, duration: timer.duration)
    }
}
