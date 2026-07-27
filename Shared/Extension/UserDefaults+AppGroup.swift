//
//  UserDefaults+AppGroup.swift
//  Iron
//
//  Created by Karim Abou Zeid on 07.12.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import Foundation

extension UserDefaults {
    /// The App Group defaults suite when available, otherwise standard defaults.
    ///
    /// Forge is a single-app build with no App Group entitlement (free signing), and no
    /// extensions read this suite, so standard defaults are a correct fallback.
    static let appGroup: UserDefaults = UserDefaults(suiteName: FileManager.appGroupIdentifier) ?? .standard
}
