//
//  WorkoutDataStorage.swift
//  WorkoutDataKit
//
//  Created by Karim Abou Zeid on 05.12.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import Foundation
import CoreData
import Combine
import os.log

public class WorkoutDataStorage {
    // make sure the model is only ever loaded once to avoid "Multiple NSEntityDescriptions Claim NSManagedObject Subclass" errors
    public static var model: NSManagedObjectModel = {
        // TODO: try to use NSManagedObjectModel.mergedModel(from: [Bundle(for: Self.self))
        guard let modelURL = Bundle(for: WorkoutDataStorage.self).url(forResource: "WorkoutData", withExtension: "momd") else { fatalError("invalid WorkoutData model URL") }
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else { fatalError("could not create managed object model from \(modelURL)") }
        return model
    }()
    
    public let persistentContainer: NSPersistentContainer
    
    private var workoutDataObserverCancellable: Cancellable?
    
    public init(storeDescription: NSPersistentStoreDescription? = nil) {
        // create the core data stack
        persistentContainer = NSPersistentContainer(name: "WorkoutData", managedObjectModel: Self.model)
        if let storeDescription = storeDescription {
            assert(storeDescription.shouldAddStoreAsynchronously == false) // this is the default value
            persistentContainer.persistentStoreDescriptions = [storeDescription]
        }
        os_log("Loading persistent store", log: .workoutDataStorage, type: .default)
        loadPersistentStores(tryToRecoverFromFailedMigration: true) { storeDescription in
            os_log("Successfully loaded persistent store: %@", log: .workoutDataStorage, type: .info, storeDescription)
        }
        // The store loads synchronously (shouldAddStoreAsynchronously is false), so it is ready here.
        Self.mergeRenamedExercises(context: persistentContainer.viewContext)
    }
    
    private func loadPersistentStores(tryToRecoverFromFailedMigration: Bool, completion: @escaping (NSPersistentStoreDescription) -> Void) {
        persistentContainer.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                os_log("Could not load persistent store", log: .workoutDataStorage, type: .fault, error)
                guard tryToRecoverFromFailedMigration && error.code == NSMigrationError else {
                    fatalError("Could not load persistent store \(storeDescription): \(error.localizedDescription)")
                }
                os_log("Trying to recover from migration error", log: .workoutDataStorage, type: .default)
                self.loadPersistentStores(tryToRecoverFromFailedMigration: false) { storeDescription in
                    Self.tryToRecoverFromMigrationError(context: self.persistentContainer.viewContext)
                    completion(storeDescription)
                }
            } else {
                completion(storeDescription)
            }
        })
    }
}

extension WorkoutDataStorage {
    /// Built-in exercises that were duplicates of another (same movement, reworded name) and have been
    /// removed from the catalog, each mapped to the exercise it was merged into. A saved reference to a
    /// removed id is rewritten to the kept id so history and routines stay intact and consolidate onto the
    /// one exercise. Editing this map is how such merges are recorded.
    public static let renamedExerciseUUIDs: [UUID: UUID] = {
        let pairs: [(removed: String, keep: String)] = [
            ("4F927F29-5D2A-5FEA-A1A4-BE999A9FAF15", "5CF92AB3-67F6-444C-A9B3-D4812B6CB06E"), // Front Raise: Cable -> Front Raises: Cable
            ("ABA5AD44-81A9-5816-9A50-D4383FDFC723", "AC43FDDC-D3C7-438D-A925-D4EF0F3CE290"), // Chest Dip -> Dips (Chest)
            ("F2447D83-C514-5FEF-BA1D-3B4863092181", "D56A7119-1885-47C6-99AC-D0501F62944E"), // Cable Crunch -> Crunch: Cable
            ("8B56E6A2-61F2-5B12-BCF2-773DE184664A", "A06460D0-17BA-4B5D-8241-D94329141399"), // Decline Crunch -> Crunch (Decline)
            ("7EAAEE8F-F27C-51FC-AFB4-51DF43171540", "4A5CE1F5-EF10-436C-8ACB-1D6D5928AEC3"), // Standing Calf Raise: Machine -> Calf Raise: Machine (Standing)
            ("D909113D-8C02-53E6-9365-9ECBC79288C0", "FB545B25-89D7-4806-ACF0-B3399DFDE3A9"), // Triceps Dip (Bench) -> Dips: Bench
            ("1A12F0A7-AE90-5E85-8B5B-D5DD918328ED", "2BBF9DB2-8BD8-456E-A0CB-749D19E5FA26"), // Close Grip Push Up -> Push Up (Close)
            ("2EB4B804-B446-58F3-B623-12B55DD5AD3A", "37DF9EB1-8E5F-404E-91B2-36210D356F95"), // Romanian Deadlift: Barbell -> Romanian Deadlift
            ("36681BE9-7C80-53B9-BE63-E6536686169A", "8B3DE466-1552-4978-A378-55F64E8CA66B"), // Leg Press (Machine) -> Leg Press
            ("32D30AE5-552D-57E2-BB14-068443BB351A", "59185216-6167-4427-AC10-38A3FDA17572"), // Pull Up (Weighted) -> Pull Up
            ("FFDFB5BE-FA4A-50D5-9DB1-60125041B95C", "8CD1F963-7570-467A-A15E-FAAFFEBF2546"), // Leg Curl (Seated, Machine) -> Leg Curl (Seated)
        ]
        return Dictionary(uniqueKeysWithValues: pairs.compactMap { pair in
            guard let removed = UUID(uuidString: pair.removed), let keep = UUID(uuidString: pair.keep) else { return nil }
            return (removed, keep)
        })
    }()

    /// Rewrites saved workout and routine exercise references from a removed duplicate to the exercise it
    /// was merged into. Returns the number of references changed. Safe to call repeatedly: once rewritten,
    /// the removed ids no longer match. Recorded set values are left untouched.
    @discardableResult
    public static func remapRenamedExercises(context: NSManagedObjectContext) throws -> Int {
        let removed = Array(renamedExerciseUUIDs.keys)
        var changed = 0
        var saveError: Error?
        context.performAndWait {
            for entityName in ["WorkoutExercise", "WorkoutRoutineExercise"] {
                let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
                request.predicate = NSPredicate(format: "exerciseUuid IN %@", removed)
                guard let objects = try? context.fetch(request) else { continue }
                for object in objects {
                    if let old = object.value(forKey: "exerciseUuid") as? UUID, let new = renamedExerciseUUIDs[old] {
                        object.setValue(new, forKey: "exerciseUuid")
                        changed += 1
                    }
                }
            }
            if context.hasChanges {
                do { try context.save() } catch { saveError = error }
            }
        }
        if let saveError = saveError { throw saveError }
        return changed
    }

    /// Runs the exercise merge once. Leaves a flag so it does not scan on every launch, but skips the flag
    /// if the save failed, so a failed run retries next launch rather than leaving references dangling.
    static func mergeRenamedExercises(context: NSManagedObjectContext) {
        let flagKey = "mergedRenamedExercisesV1"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        do {
            let changed = try remapRenamedExercises(context: context)
            if changed > 0 {
                os_log("Merged %d references from removed duplicate exercises", log: .migration, type: .info, changed)
            }
            UserDefaults.standard.set(true, forKey: flagKey)
        } catch {
            os_log("Could not merge renamed exercises, will retry next launch: %@", log: .migration, type: .error, error as NSError)
        }
    }

    static func tryToRecoverFromMigrationError(context: NSManagedObjectContext) {
        context.performAndWait {
            let workoutRequest: NSFetchRequest<Workout> = Workout.fetchRequest()
            workoutRequest.predicate = NSPredicate(format: "\(#keyPath(Workout.uuid)) == NULL")
            let workouts = try? context.fetch(workoutRequest)
            workouts?.forEach { $0.uuid = UUID() }
            (workouts?.count).map { os_log("Adding UUIDs for %d workouts", log: .migration, type: .info, $0) }
            
            let workoutExerciseRequest: NSFetchRequest<WorkoutExercise> = WorkoutExercise.fetchRequest()
            workoutExerciseRequest.predicate = NSPredicate(format: "\(#keyPath(WorkoutExercise.uuid)) == NULL")
            let workoutExercises = try? context.fetch(workoutExerciseRequest)
            workoutExercises?.forEach { $0.uuid = UUID() }
            (workoutExercises?.count).map { os_log("Adding UUIDs for %d workout exercises", log: .migration, type: .info, $0) }

            let workoutSetRequest: NSFetchRequest<WorkoutSet> = WorkoutSet.fetchRequest()
            workoutSetRequest.predicate = NSPredicate(format: "\(#keyPath(WorkoutSet.uuid)) == NULL")
            let workoutSets = try? context.fetch(workoutSetRequest)
            workoutSets?.forEach { $0.uuid = UUID() }
            (workoutSets?.count).map { os_log("Adding UUIDs for %d workout sets", log: .migration, type: .info, $0) }
            
            let workoutPlanRequest: NSFetchRequest<WorkoutPlan> = WorkoutPlan.fetchRequest()
            workoutPlanRequest.predicate = NSPredicate(format: "\(#keyPath(WorkoutPlan.uuid)) == NULL")
            let workoutPlans = try? context.fetch(workoutPlanRequest)
            workoutPlans?.forEach { $0.uuid = UUID() }
            (workoutPlans?.count).map { os_log("Adding UUIDs for %d workout plans", log: .migration, type: .info, $0) }
            
            let workoutRoutineRequest: NSFetchRequest<WorkoutRoutine> = WorkoutRoutine.fetchRequest()
            workoutRoutineRequest.predicate = NSPredicate(format: "\(#keyPath(WorkoutRoutine.uuid)) == NULL")
            let workoutRoutines = try? context.fetch(workoutRoutineRequest)
            workoutRoutines?.forEach { $0.uuid = UUID() }
            (workoutRoutines?.count).map { os_log("Adding UUIDs for %d workout routines", log: .migration, type: .info, $0) }
            
            let workoutRoutineExerciseRequest: NSFetchRequest<WorkoutRoutineExercise> = WorkoutRoutineExercise.fetchRequest()
            workoutRoutineExerciseRequest.predicate = NSPredicate(format: "\(#keyPath(WorkoutRoutineExercise.uuid)) == NULL")
            let workoutRoutineExercises = try? context.fetch(workoutRoutineExerciseRequest)
            workoutRoutineExercises?.forEach { $0.uuid = UUID() }
            (workoutRoutineExercises?.count).map { os_log("Adding UUIDs for %d workout routine exercises", log: .migration, type: .info, $0) }
            
            let workoutRoutineSetRequest: NSFetchRequest<WorkoutRoutineSet> = WorkoutRoutineSet.fetchRequest()
            workoutRoutineSetRequest.predicate = NSPredicate(format: "\(#keyPath(WorkoutRoutineSet.uuid)) == NULL")
            let workoutRoutineSets = try? context.fetch(workoutRoutineSetRequest)
            workoutRoutineSets?.forEach { $0.uuid = UUID() }
            (workoutRoutineSets?.count).map { os_log("Adding UUIDs for %d workout routine sets", log: .migration, type: .info, $0) }
        }
    }
}

import os.signpost
extension WorkoutDataStorage {
    public static func sendObjectsWillChange(changes: NSManagedObjectContext.ObjectChanges) {
        for changedObject in changes.inserted.union(changes.updated).union(changes.deleted) {
            // instruments debugging
            let signPostID = OSSignpostID(log: .coreDataMonitor)
            let signPostName: StaticString = "process single workout data change"
            os_signpost(.begin, log: .coreDataMonitor, name: signPostName, signpostID: signPostID, "%@", changedObject.objectID)
            defer { os_signpost(.end, log: .coreDataMonitor, name: signPostName, signpostID: signPostID) }
            //
            
            changedObject.objectWillChange.send()
            if let workout = changedObject as? Workout {
                workout.workoutExercises?.compactMap { $0 as? WorkoutExercise }
                    .forEach { workoutExercise in
                        workoutExercise.objectWillChange.send()
                        workoutExercise.workoutSets?.compactMap { $0 as? WorkoutSet }
                            .forEach { $0.objectWillChange.send() }
                }
            } else if let workoutExercise = changedObject as? WorkoutExercise {
                workoutExercise.workout?.objectWillChange.send()
                workoutExercise.workoutSets?.compactMap { $0 as? WorkoutSet }
                    .forEach { $0.objectWillChange.send() }
            } else if let workoutSet = changedObject as? WorkoutSet {
                workoutSet.workoutExercise?.objectWillChange.send()
                workoutSet.workoutExercise?.workout?.objectWillChange.send()
            } else if let workoutPlan = changedObject as? WorkoutPlan {
                workoutPlan.workoutRoutines?.compactMap { $0 as? WorkoutRoutine }
                    .forEach { workoutRoutine in
                        workoutRoutine.objectWillChange.send()
                        workoutRoutine.workoutRoutineExercises?.compactMap { $0 as? WorkoutRoutineExercise }
                            .forEach { workoutRoutineExercise in
                                workoutRoutineExercise.objectWillChange.send()
                                workoutRoutineExercise.workoutRoutineSets?.compactMap { $0 as? WorkoutRoutineSet }
                                    .forEach { $0.objectWillChange.send() }
                        }
                }
            } else if let workoutRoutine = changedObject as? WorkoutRoutine {
                workoutRoutine.workoutPlan?.objectWillChange.send()
                workoutRoutine.workoutRoutineExercises?.compactMap { $0 as? WorkoutRoutineExercise }
                    .forEach { workoutRoutineExercise in
                        workoutRoutineExercise.objectWillChange.send()
                        workoutRoutineExercise.workoutRoutineSets?.compactMap { $0 as? WorkoutRoutineSet }
                            .forEach { $0.objectWillChange.send() }
                }
            } else if let workoutRoutineExercise = changedObject as? WorkoutRoutineExercise {
                workoutRoutineExercise.workoutRoutine?.objectWillChange.send()
                workoutRoutineExercise.workoutRoutine?.workoutPlan?.objectWillChange.send()
                workoutRoutineExercise.workoutRoutineSets?.compactMap { $0 as? WorkoutRoutineSet }
                    .forEach { $0.objectWillChange.send() }
            } else if let workoutRoutineSet = changedObject as? WorkoutRoutineSet {
                workoutRoutineSet.workoutRoutineExercise?.objectWillChange.send()
                workoutRoutineSet.workoutRoutineExercise?.workoutRoutine?.objectWillChange.send()
                workoutRoutineSet.workoutRoutineExercise?.workoutRoutine?.workoutPlan?.objectWillChange.send()
            } else {
                os_log("Change for unknown NSManagedObject: %@", log: .coreDataMonitor, type: .error, changedObject)
            }
        }
    }
}
