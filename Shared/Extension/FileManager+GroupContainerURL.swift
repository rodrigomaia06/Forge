//
//  FileManager+GroupContainerURL.swift
//  Iron
//
//  Created by Karim Abou Zeid on 06.12.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import Foundation

extension FileManager {
    static var appGroupIdentifier = "group.com.kabouzeid.Iron"
    
    /// The App Group container when available, otherwise the app's own sandbox container.
    ///
    /// Forge is a single-app build signed with a free Apple ID, which cannot use App Groups.
    /// Without that entitlement the shared container can't be created, so we fall back to the
    /// app's own container (`NSHomeDirectory()`), which has the same `Library/Application Support`
    /// layout. The App Group is still preferred when present (e.g. a build that has the
    /// entitlement), so this stays correct either way.
    var appGroupContainerURL: URL {
        if let containerURL = containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) {
            return containerURL
        }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }
    
    var appGroupContainerApplicationSupportURL: URL {
        let directory = appGroupContainerURL
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
        
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            fatalError("could not create \(directory)")
        }
        
        return directory
    }
}
