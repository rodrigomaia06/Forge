//
//  NSManagedObjectContext+save.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 26.07.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import Foundation
import CoreData
import os.log

extension NSManagedObjectContext {
    func saveOrCrash () {
        if hasChanges {
            HangMonitor.note("NSManagedObjectContext.save begin")
            defer { HangMonitor.note("NSManagedObjectContext.save end") }
            do {
                try save()
            } catch {
                let description = Self.descriptionWithDetailedErrors(error: error as NSError)
                os_log("Could not save context: %@", log: .workoutData, type: .error, description)
                // Roll back to the last saved state so the store is never left partially written, then
                // tell the user in plain language instead of crashing.
                rollback()
                AppErrorPresenter.shared.present(
                    title: "Change not saved",
                    message: "Something went wrong saving that change, so your previous data was kept. Please try again."
                )
            }
        }
    }
}

extension NSManagedObjectContext {
    static func descriptionWithDetailedErrors(error: NSError) -> String {
        var append: String?
        if let detailedErrors = (error as NSError).userInfo[NSDetailedErrorsKey] as? [NSError] {
            let detailedString = detailedErrors
                .map { descriptionWithEntityName(error: $0) }
                .joined(separator: "\n")
            append = " Detailed Errors:\n\(detailedString)\n"
        }
        return descriptionWithEntityName(error: error) + (append ?? "")
    }
    
    private static func descriptionWithEntityName(error: NSError) -> String {
        let entityName = (error.userInfo[NSValidationObjectErrorKey] as? NSManagedObject)?.entity.name
        return "\(entityName.map { "\($0):" } ?? "") \(error.localizedDescription)"
    }
}
