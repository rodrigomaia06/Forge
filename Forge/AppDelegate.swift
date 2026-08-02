//
//  AppDelegate.swift
//  Rhino Fit
//
//  Created by Karim Abou Zeid on 14.01.18.
//  Copyright © 2018 Karim Abou Zeid Software. All rights reserved.
//

import UIKit
import CoreData
import Combine
import WorkoutDataKit
import os.log

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Watches the main thread so a freeze leaves a record behind. A force-quit kills the process
        // without a crash report, so there is otherwise nothing to read afterwards.
        HangMonitor.shared.start()

        // disable the transparent tab bar in iOS 15, there is a bug and it doesn't work correctly with the TimerBannerView for now
        if #available(iOS 15.0, *) {
            if #unavailable(iOS 16.0) { // fixed in iOS 16
                let barAppearance = UITabBarAppearance()
                barAppearance.configureWithOpaqueBackground()
                UITabBar.appearance().scrollEdgeAppearance = barAppearance
            }
        }
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    // MARK: - Custom
    
    static var instance: AppDelegate {
        UIApplication.shared.delegate as! AppDelegate
    }
}
