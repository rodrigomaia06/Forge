//
//  WorkoutPlan.swift
//  WorkoutDataKit
//
//  Created by Karim Abou Zeid on 21.12.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import CoreData

extension WorkoutRoutine {
    /// Identity for SwiftUI, from the uuid rather than the objectID.
    ///
    /// A newly inserted object has a temporary objectID that Core Data replaces with a permanent one the
    /// next time the context saves. Keyed on that, every save gave a set or exercise created during the
    /// workout a brand new identity: SwiftUI tore the row down and built a fresh one, and a text field
    /// being edited inside it was destroyed while it was still first responder. That leaves the keyboard
    /// up with nothing behind it. The uuid is assigned at creation and never changes.
    public var id: String { uuid?.uuidString ?? objectID.uriRepresentation().absoluteString }
}

public class WorkoutRoutine: NSManagedObject, Codable {
    public class func create(context: NSManagedObjectContext) -> WorkoutRoutine {
        let workoutRoutine = WorkoutRoutine(context: context)
        workoutRoutine.uuid = UUID()
        return workoutRoutine
    }

    /// Before this routine is deleted, keep any finished workout that borrowed its name from this routine
    /// readable by fixing that name onto the workout. The relationships are still intact here, so the plan
    /// and routine names are available. A workout with its own name is left as it is.
    public override func prepareForDeletion() {
        super.prepareForDeletion()
        for case let workout as Workout in (workouts ?? []) {
            workout.snapshotRoutineTitleIfNeeded()
        }
    }

    /// A deep copy of this routine (title, comment, custom fields, exercises and their sets), not yet
    /// attached to a plan. The caller adds it to a plan's ordered routines.
    public func duplicate(context: NSManagedObjectContext) -> WorkoutRoutine {
        let copy = WorkoutRoutine.create(context: context)
        copy.title = title
        copy.comment = comment
        copy.customAttributes = customAttributes
        // Build the ordered relationships by setting each child's to-one inverse (which appends it in
        // order). Assigning an NSOrderedSet does not maintain the required inverse, so the copy would
        // fail validation on save.
        var supersetIDMap: [UUID: UUID] = [:]
        for exercise in (workoutRoutineExercises?.compactMap { $0 as? WorkoutRoutineExercise } ?? []) {
            let exerciseCopy = WorkoutRoutineExercise.create(context: context)
            exerciseCopy.exerciseUuid = exercise.exerciseUuid
            exerciseCopy.comment = exercise.comment
            exerciseCopy.supersetComment = exercise.supersetComment
            exerciseCopy.workoutRoutine = copy
            if let group = exercise.supersetUUID {
                exerciseCopy.supersetUUID = supersetIDMap[group] ?? {
                    let fresh = UUID(); supersetIDMap[group] = fresh; return fresh
                }()
            }
            for set in (exercise.workoutRoutineSets?.compactMap { $0 as? WorkoutRoutineSet } ?? []) {
                let setCopy = WorkoutRoutineSet.create(context: context)
                setCopy.minRepetitions = set.minRepetitions
                setCopy.maxRepetitions = set.maxRepetitions
                setCopy.tagValue = set.tagValue
                setCopy.comment = set.comment
                setCopy.workoutRoutineExercise = exerciseCopy
            }
        }
        return copy
    }
    
    public var fallbackTitle: String? {
        guard let index = workoutPlan?.workoutRoutines?.index(of: self), index != NSNotFound else { return nil }
        guard let letters = toLetters(from: index) else { return nil }
        return "Routine \(letters)"
    }
    
    private func toLetters(from index: Int) -> String? {
        guard index >= 0 else { return nil }

        let quotient: Int = index / 26
        let remainder: Int = index % 26
        
        guard let scalar = UnicodeScalar(Int(UnicodeScalar("A").value) + remainder) else {
            assertionFailure("This should never happen")
            return nil
        }
        let letter = String(Character(scalar))
        
        if quotient == 0 {
            return letter
        }
        
        guard let prefix = toLetters(from: quotient - 1) else { return nil }
        return prefix + letter
    }

    
    public var displayTitle: String {
        title ?? fallbackTitle ?? "Workout Routine"
    }
    
    public func subtitle(in exercises: [Exercise]) -> String {
        let s = workoutRoutineExercises?
            .compactMap { $0 as? WorkoutRoutineExercise }
            .compactMap { $0.exercise(in: exercises)?.title }
            .joined(separator: ", ") ?? ""
        
        return s.isEmpty ? "Empty" : s
    }
    
    public func createWorkout(context: NSManagedObjectContext) -> Workout {
        let workout = Workout.create(context: context)
        workout.comment = self.comment
        // Seed the workout with the routine's custom fields (location, mood, ...) so a plan's defaults
        // carry into the session. The user can still edit them on the live workout.
        workout.customAttributes = self.customAttributes
        // NOTE: don't set title here, it should be inferred automatically by the relation ship
        
        if let workoutRoutineExercises = workoutRoutineExercises?.compactMap({ $0 as? WorkoutRoutineExercise }) {
            // Carry any superset grouping into the workout, giving each group a fresh id so this workout's
            // grouping is independent of the routine and of other workouts started from it.
            var supersetIDMap: [UUID: UUID] = [:]
            // copy the exercises
            for workoutRoutineExercise in workoutRoutineExercises {
                let workoutExercise = WorkoutExercise.create(context: context)
                workout.addToWorkoutExercises(workoutExercise)
                workoutExercise.exerciseUuid = workoutRoutineExercise.exerciseUuid
                workoutExercise.comment = workoutRoutineExercise.comment
                workoutExercise.assistedValue = workoutRoutineExercise.assistedValue
                workoutExercise.supersetComment = workoutRoutineExercise.supersetComment
                if let routineGroup = workoutRoutineExercise.supersetUUID {
                    workoutExercise.supersetUUID = supersetIDMap[routineGroup] ?? {
                        let fresh = UUID(); supersetIDMap[routineGroup] = fresh; return fresh
                    }()
                }

                if let workoutRoutineSets = workoutRoutineExercise.workoutRoutineSets?.compactMap({ $0 as? WorkoutRoutineSet }) {
                    // copy the sets
                    for workoutRoutineSet in workoutRoutineSets {
                        let workoutSet = WorkoutSet.create(context: context)
                        workoutSet.workoutExercise = workoutExercise
                        workoutSet.isCompleted = false
                        workoutSet.maxTargetRepetitions = workoutRoutineSet.maxRepetitions
                        workoutSet.minTargetRepetitions = workoutRoutineSet.minRepetitions
                        workoutSet.tagValue = workoutRoutineSet.tagValue
                        workoutSet.comment = workoutRoutineSet.comment
                    }
                }
            }
        }
        
        addToWorkouts(workout)
        return workout
    }
    
    // MARK: - Codable
    
       private enum CodingKeys: String, CodingKey {
           case uuid
           case title
           case comment
           case exercises
       }
       
       required convenience public init(from decoder: Decoder) throws {
           guard let contextKey = CodingUserInfoKey.managedObjectContextKey,
               let context = decoder.userInfo[contextKey] as? NSManagedObjectContext,
               let entity = NSEntityDescription.entity(forEntityName: "WorkoutRoutine", in: context)
               else {
               throw CodingUserInfoKey.DecodingError.managedObjectContextMissing
           }
           self.init(entity: entity, insertInto: context)
           
           let container = try decoder.container(keyedBy: CodingKeys.self)
           uuid = try container.decodeIfPresent(UUID.self, forKey: .uuid) ?? UUID() // make sure we always have an UUID
           title = try container.decodeIfPresent(String.self, forKey: .title)
           comment = try container.decodeIfPresent(String.self, forKey: .comment)
           workoutRoutineExercises = NSOrderedSet(array: try container.decodeIfPresent([WorkoutRoutineExercise].self, forKey: .exercises) ?? [])
       }
       
       public func encode(to encoder: Encoder) throws {
           var container = encoder.container(keyedBy: CodingKeys.self)
           try container.encode(uuid ?? UUID(), forKey: .uuid)
           try container.encodeIfPresent(title, forKey: .title)
           try container.encodeIfPresent(comment, forKey: .comment)
           try container.encodeIfPresent(workoutRoutineExercises?.array.compactMap { $0 as? WorkoutRoutineExercise }, forKey: .exercises)
       }
}

// MARK: - Keeping a routine in step with a workout

extension WorkoutRoutine {
    /// True when the workout's exercises or sets no longer match this routine in count or order, so the
    /// routine is out of date compared with what was actually done.
    public func differs(fromWorkout workout: Workout) -> Bool {
        let routineExercises = workoutRoutineExercises?.compactMap { $0 as? WorkoutRoutineExercise } ?? []
        let workoutExercises = workout.workoutExercises?.compactMap { $0 as? WorkoutExercise } ?? []
        guard routineExercises.count == workoutExercises.count else { return true }
        for (routineExercise, workoutExercise) in zip(routineExercises, workoutExercises) {
            if routineExercise.exerciseUuid != workoutExercise.exerciseUuid { return true }
            let routineSetCount = routineExercise.workoutRoutineSets?.count ?? 0
            let workoutSetCount = workoutExercise.workoutSets?.count ?? 0
            if routineSetCount != workoutSetCount { return true }
        }
        // The superset grouping is part of the routine's shape. Compare which adjacent exercises are
        // grouped (ids differ between routine and workout, so compare the boundaries, not the ids).
        let routineGrouping = zip(routineExercises, routineExercises.dropFirst()).map { $0.supersetUUID != nil && $0.supersetUUID == $1.supersetUUID }
        let workoutGrouping = zip(workoutExercises, workoutExercises.dropFirst()).map { $0.supersetUUID != nil && $0.supersetUUID == $1.supersetUUID }
        if routineGrouping != workoutGrouping { return true }
        return false
    }

    /// Rebuilds this routine's exercises and sets to match the workout, in order, so it reflects what was
    /// actually done. Routine-owned notes and set types stay on the routine; a workout can change the
    /// structure and rep targets, but the routine editor remains the only place that changes template
    /// comments and set types.
    public func update(fromWorkout workout: Workout) {
        guard let context = managedObjectContext else { return }
        let existingExercises = workoutRoutineExercises?.compactMap { $0 as? WorkoutRoutineExercise } ?? []
        var unusedExercises = existingExercises
        var updatedExercises: [WorkoutRoutineExercise] = []
        var supersetIDMap: [UUID: UUID] = [:]
        for (index, workoutExercise) in (workout.workoutExercises?.compactMap { $0 as? WorkoutExercise } ?? []).enumerated() {
            let routineExercise: WorkoutRoutineExercise
            if index < existingExercises.count, existingExercises[index].exerciseUuid == workoutExercise.exerciseUuid {
                routineExercise = existingExercises[index]
                unusedExercises.removeAll { $0 == routineExercise }
            } else if let matchIndex = unusedExercises.firstIndex(where: { $0.exerciseUuid == workoutExercise.exerciseUuid }) {
                routineExercise = unusedExercises.remove(at: matchIndex)
            } else {
                routineExercise = WorkoutRoutineExercise.create(context: context)
                routineExercise.assistedValue = workoutExercise.assistedValue
            }
            routineExercise.exerciseUuid = workoutExercise.exerciseUuid
            routineExercise.workoutRoutine = self
            // Carry the workout's superset grouping onto the routine, with fresh ids for the routine.
            if let group = workoutExercise.supersetUUID {
                routineExercise.supersetUUID = supersetIDMap[group] ?? {
                    let fresh = UUID(); supersetIDMap[group] = fresh; return fresh
                }()
            } else {
                routineExercise.supersetUUID = nil
            }

            let existingSets = routineExercise.workoutRoutineSets?.compactMap { $0 as? WorkoutRoutineSet } ?? []
            var updatedSets: [WorkoutRoutineSet] = []
            for (setIndex, workoutSet) in (workoutExercise.workoutSets?.compactMap { $0 as? WorkoutSet } ?? []).enumerated() {
                let routineSet = setIndex < existingSets.count ? existingSets[setIndex] : WorkoutRoutineSet.create(context: context)
                // Keep the planned rep range, falling back to the reps actually done.
                routineSet.minRepetitionsValue = workoutSet.minTargetRepetitionsValue ?? workoutSet.repetitions?.int16Value
                routineSet.maxRepetitionsValue = workoutSet.maxTargetRepetitionsValue ?? workoutSet.repetitions?.int16Value
                routineSet.workoutRoutineExercise = routineExercise
                updatedSets.append(routineSet)
            }
            for staleSet in existingSets.dropFirst(updatedSets.count) {
                routineExercise.removeFromWorkoutRoutineSets(staleSet)
                context.delete(staleSet)
            }
            routineExercise.workoutRoutineSets = NSOrderedSet(array: updatedSets)
            updatedExercises.append(routineExercise)
        }
        for staleExercise in unusedExercises {
            removeFromWorkoutRoutineExercises(staleExercise)
            context.delete(staleExercise)
        }
        workoutRoutineExercises = NSOrderedSet(array: updatedExercises)
    }
}
