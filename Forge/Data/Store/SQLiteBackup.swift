//
//  SQLiteBackup.swift
//  Forge
//
//  Plain-SQLite database export/import. The store is already a SQLite database; this
//  produces a single self-contained `.sqlite` file (WAL folded in) that opens and edits
//  in any SQLite tool, and imports one back by validating it against the current model,
//  taking a safety copy of the existing data, then atomically replacing the store.
//
//  NOTE: import replaces the on-disk store; the app must relaunch to load the new data.
//  This is data-critical code — cover it with tests before relying on it.
//

import Foundation
import CoreData
import WorkoutDataKit
import os.log

enum SQLiteBackup {
    static let fileExtension = "sqlite"

    enum BackupError: LocalizedError {
        case noStore
        case incompatibleDatabase
        case duplicateIdentifiers

        var errorDescription: String? {
            switch self {
            case .noStore: return "The workout database could not be found."
            case .incompatibleDatabase: return "This file isn't a compatible Forge database."
            case .duplicateIdentifiers: return "This backup contains duplicate records and can't be imported safely. Your current data was not changed."
            }
        }
    }

    /// What an incoming backup contains, shown to the user before the destructive replace.
    struct ImportSummary {
        let workouts: Int
        let routines: Int
        let customExercises: Int
    }

    /// Opens the incoming file read-only and validates it against the current model, rejects duplicate
    /// identifiers, and returns its entity counts. Does not touch the live store.
    static func inspect(from srcURL: URL) throws -> ImportSummary {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store: NSPersistentStore
        do {
            store = try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: srcURL,
                options: [NSReadOnlyPersistentStoreOption: true]
            )
        } catch {
            os_log("Rejected incompatible import: %@", log: .backup, type: .error, error.localizedDescription)
            throw BackupError.incompatibleDatabase
        }
        defer { try? coordinator.remove(store) }

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        var summary: ImportSummary?
        var thrown: Error?
        context.performAndWait {
            do {
                // Duplicate top-level identifiers indicate a corrupt backup; refuse before replacing.
                if try hasDuplicateUUIDs(entity: "Workout", in: context)
                    || hasDuplicateUUIDs(entity: "WorkoutRoutine", in: context) {
                    throw BackupError.duplicateIdentifiers
                }
                summary = ImportSummary(
                    workouts: try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "Workout")),
                    routines: try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "WorkoutRoutine")),
                    customExercises: try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "CustomExercise"))
                )
            } catch {
                thrown = error
            }
        }
        if let thrown { throw thrown }
        guard let summary else { throw BackupError.incompatibleDatabase }
        return summary
    }

    private static func hasDuplicateUUIDs(entity: String, in context: NSManagedObjectContext) throws -> Bool {
        let request = NSFetchRequest<NSDictionary>(entityName: entity)
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["uuid"]
        let uuids = try context.fetch(request).compactMap { $0["uuid"] as? UUID }
        return Set(uuids).count != uuids.count
    }

    private static var coordinator: NSPersistentStoreCoordinator {
        WorkoutDataStorage.shared.persistentContainer.persistentStoreCoordinator
    }

    private static var model: NSManagedObjectModel {
        WorkoutDataStorage.shared.persistentContainer.managedObjectModel
    }

    private static func liveStoreURL() throws -> URL {
        guard let url = coordinator.persistentStores.first?.url else { throw BackupError.noStore }
        return url
    }

    /// Writes a single-file copy of the current database to `destURL`, leaving the live store intact.
    static func export(to destURL: URL) throws {
        let liveURL = try liveStoreURL()
        try? FileManager.default.removeItem(at: destURL)

        // A dedicated coordinator opens the live store read-only and migrates a copy out with a
        // plain rollback journal, so the result is one self-contained .sqlite (no -wal/-shm).
        let exportCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let source = try exportCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: liveURL,
            options: [NSReadOnlyPersistentStoreOption: true]
        )
        try exportCoordinator.migratePersistentStore(
            source,
            to: destURL,
            options: [NSSQLitePragmasOption: ["journal_mode": "DELETE"]],
            withType: NSSQLiteStoreType
        )
        os_log("Exported database to %@", log: .backup, type: .default, destURL.lastPathComponent)
    }

    /// Validates an incoming `.sqlite`, backs up the current data, then replaces the live store.
    /// The caller must relaunch the app afterwards to load the imported data.
    static func `import`(from srcURL: URL) throws {
        // 1. Validate: the file must open against the current model.
        let validationCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        do {
            let store = try validationCoordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: srcURL,
                options: [NSReadOnlyPersistentStoreOption: true]
            )
            try validationCoordinator.remove(store)
        } catch {
            os_log("Rejected incompatible import: %@", log: .backup, type: .error, error.localizedDescription)
            throw BackupError.incompatibleDatabase
        }

        let liveURL = try liveStoreURL()

        // 2. Safety copy of the current data, so a bad import is recoverable.
        let safetyURL = liveURL.deletingLastPathComponent()
            .appendingPathComponent("WorkoutData-pre-import")
            .appendingPathExtension(fileExtension)
        try? FileManager.default.removeItem(at: safetyURL)
        try coordinator.replacePersistentStore(
            at: safetyURL, destinationOptions: nil,
            withPersistentStoreFrom: liveURL, sourceOptions: nil,
            ofType: NSSQLiteStoreType
        )
        os_log("Wrote pre-import safety backup", log: .backup, type: .default)

        // 3. Atomically replace the live store with the imported one.
        try coordinator.replacePersistentStore(
            at: liveURL, destinationOptions: nil,
            withPersistentStoreFrom: srcURL, sourceOptions: nil,
            ofType: NSSQLiteStoreType
        )
        os_log("Replaced live store with imported database", log: .backup, type: .default)
    }

    /// Suggested export filename, e.g. `Forge 2026-07-28.sqlite`.
    static func suggestedExportName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "Forge \(formatter.string(from: date)).\(fileExtension)"
    }
}
