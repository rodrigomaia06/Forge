//
//  OSLog+Logs.swift
//  Iron
//
//  Created by Karim Abou Zeid on 05.03.20.
//  Copyright © 2020 Karim Abou Zeid Software. All rights reserved.
//

import Foundation
import os.log

extension OSLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.kabouzeid.Iron.nobundle"
    
    static let migration = OSLog(subsystem: subsystem, category: "Migration")
    static let backup = OSLog(subsystem: subsystem, category: "Backup")
    static let workoutData = OSLog(subsystem: subsystem, category: "Workout Data")
}
