//
//  WorkoutPlan.swift
//  WorkoutDataKit
//
//  Created by Karim Abou Zeid on 21.12.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import CoreData

extension WorkoutPlan {
    /// Identity for SwiftUI, from the uuid rather than the objectID.
    ///
    /// A newly inserted object has a temporary objectID that Core Data replaces with a permanent one the
    /// next time the context saves. Keyed on that, every save gave a set or exercise created during the
    /// workout a brand new identity: SwiftUI tore the row down and built a fresh one, and a text field
    /// being edited inside it was destroyed while it was still first responder. That leaves the keyboard
    /// up with nothing behind it. The uuid is assigned at creation and never changes.
    public var id: String { uuid?.uuidString ?? objectID.uriRepresentation().absoluteString }
}

public class WorkoutPlan: NSManagedObject, Codable {
    public class func create(context: NSManagedObjectContext) -> WorkoutPlan {
        let workoutPlan = WorkoutPlan(context: context)
        workoutPlan.uuid = UUID()
        return workoutPlan
    }

    /// Deleting a plan cascades to its routines. Snapshot the plan-and-routine name onto any borrowing
    /// workout here first, while the plan is still connected, so the full name is captured before the
    /// cascade nulls each routine's link. (The routine's own prepareForDeletion then finds nothing left
    /// to do for those workouts.)
    public override func prepareForDeletion() {
        super.prepareForDeletion()
        for case let routine as WorkoutRoutine in (workoutRoutines ?? []) {
            for case let workout as Workout in (routine.workouts ?? []) {
                workout.snapshotRoutineTitleIfNeeded()
            }
        }
    }
    
    public var displayTitle: String {
        title ?? "Workout Plan"
    }
    
    public func duplicate(context: NSManagedObjectContext) -> WorkoutPlan {
        let workoutPlanCopy = WorkoutPlan.create(context: context)
        workoutPlanCopy.title = self.title
        workoutPlanCopy.workoutRoutines = NSOrderedSet(array:
            self.workoutRoutines?
                .compactMap { $0 as? WorkoutRoutine }
                .map { workoutRoutine in
                    let workoutRoutineCopy = WorkoutRoutine.create(context: context)
                    workoutRoutineCopy.title = workoutRoutine.title
                    workoutRoutineCopy.comment = workoutRoutine.comment
                    // Fresh superset ids for the copied routine, preserving which exercises are grouped.
                    var supersetIDMap: [UUID: UUID] = [:]
                    workoutRoutineCopy.workoutRoutineExercises = NSOrderedSet(array:
                        workoutRoutine.workoutRoutineExercises?
                            .compactMap { $0 as? WorkoutRoutineExercise }
                            .map { workoutRoutineExercise in
                                let workoutRoutineExerciseCopy = WorkoutRoutineExercise.create(context: context)
                                workoutRoutineExerciseCopy.exerciseUuid = workoutRoutineExercise.exerciseUuid
                                workoutRoutineExerciseCopy.comment = workoutRoutineExercise.comment
                                workoutRoutineExerciseCopy.supersetComment = workoutRoutineExercise.supersetComment
                                if let group = workoutRoutineExercise.supersetUUID {
                                    workoutRoutineExerciseCopy.supersetUUID = supersetIDMap[group] ?? {
                                        let fresh = UUID(); supersetIDMap[group] = fresh; return fresh
                                    }()
                                }
                                workoutRoutineExerciseCopy.workoutRoutineSets = NSOrderedSet(array:
                                    workoutRoutineExercise.workoutRoutineSets?
                                        .compactMap { $0 as? WorkoutRoutineSet }
                                        .map { workoutRoutineSet in
                                            let workoutRoutineSetCopy  = WorkoutRoutineSet.create(context: context)
                                            workoutRoutineSetCopy.maxRepetitions = workoutRoutineSet.maxRepetitions
                                            workoutRoutineSetCopy.minRepetitions = workoutRoutineSet.minRepetitions
                                            workoutRoutineSetCopy.tagValue = workoutRoutineSet.tagValue
                                            workoutRoutineSetCopy.comment = workoutRoutineSet.comment
                                            return workoutRoutineSetCopy
                                        }
                                ?? [])
                                return workoutRoutineExerciseCopy
                            }
                    ?? [])
                    return workoutRoutineCopy
                }
        ?? [])
        return workoutPlanCopy
    }
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case uuid
        case title
        case routines
    }
    
    required convenience public init(from decoder: Decoder) throws {
        guard let contextKey = CodingUserInfoKey.managedObjectContextKey,
            let context = decoder.userInfo[contextKey] as? NSManagedObjectContext,
            let entity = NSEntityDescription.entity(forEntityName: "WorkoutPlan", in: context)
            else {
            throw CodingUserInfoKey.DecodingError.managedObjectContextMissing
        }
        self.init(entity: entity, insertInto: context)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decodeIfPresent(UUID.self, forKey: .uuid) ?? UUID() // make sure we always have an UUID
        title = try container.decodeIfPresent(String.self, forKey: .title)
        workoutRoutines = NSOrderedSet(array: try container.decodeIfPresent([WorkoutRoutine].self, forKey: .routines) ?? [])
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid ?? UUID(), forKey: .uuid)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(workoutRoutines?.array.compactMap { $0 as? WorkoutRoutine }, forKey: .routines)
    }
}
