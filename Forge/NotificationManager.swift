//
//  NotificationManager.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 03.09.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import UserNotifications
import AudioToolbox

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
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = "You've rested enough!"
            if let totalTime = totalTime, let totalTimeString = restTimerDurationFormatter.string(from: totalTime) {
                content.title += " (\(totalTimeString))"
            }
            content.body = "Back to work."
            if settings.soundSetting == .enabled, SettingsStore.shared.restTimerSound {
                content.sound = UNNotificationSound.default
            }
            content.categoryIdentifier = NotificationCategoryIdentifier.restTimerUp.rawValue
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .timeSensitive
            }
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remainingTime, repeats: false)
            
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

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        guard notification.request.identifier == NotificationIdentifier.restTimerUp.rawValue else {
            completionHandler([])
            return
        }
        // The rest timer ended while Forge is in the foreground. Fire the configured haptic, and play
        // the classic iPhone tri-tone alert in-app. The notification carries no sound here so it does
        // not double up. (Background notifications can only use the system default; see the request.)
        if SettingsStore.shared.restTimerHaptic {
            DispatchQueue.main.async { Haptics.success() }
        }
        if SettingsStore.shared.restTimerSound {
            DispatchQueue.main.async { AudioServicesPlaySystemSound(1007) } // 1007 = classic tri-tone
        }
        completionHandler([.alert])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        defer { completionHandler() }
        
        guard let duration = RestTimerStore.shared.restTimerDuration else { return}
        
        guard let actionIdentifier = NotificationActionIdentifier(rawValue: response.actionIdentifier) else { return }
        
        switch actionIdentifier {
        case .restTimerAdd30:
            RestTimerStore.shared.restTimerDuration = duration + 30
        case .restTimerAdd60:
            RestTimerStore.shared.restTimerDuration = duration + 60
        case .restTimerAdd90:
            RestTimerStore.shared.restTimerDuration = duration + 90
        }
    }
}
