//
//  WorkoutExercise.swift
//  Rhino Fit
//
//  Created by Karim Abou Zeid on 14.02.18.
//  Copyright © 2018 Karim Abou Zeid Software. All rights reserved.
//

import CoreData
import Combine

extension WorkoutExercise {
    public var id: NSManagedObjectID { self.objectID }
}

public class WorkoutExercise: NSManagedObject, Codable {
    public static func historyFetchRequest(of exerciseUuid: UUID?, from: Date? = nil, until: Date? = nil) -> NSFetchRequest<WorkoutExercise> {
        let request: NSFetchRequest<WorkoutExercise> = WorkoutExercise.fetchRequest()
        var predicate = NSPredicate(format: "\(#keyPath(WorkoutExercise.workout.isCurrentWorkout)) != %@ AND \(#keyPath(WorkoutExercise.exerciseUuid)) == %@", NSNumber(booleanLiteral: true), (exerciseUuid ?? UUID()) as CVarArg)
        if let from = from {
            let fromPredicate = NSPredicate(format: "\(#keyPath(WorkoutExercise.workout.start)) >= %@", from as NSDate)
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, fromPredicate])
        }
        if let until = until {
            let untilPredicate = NSPredicate(format: "\(#keyPath(WorkoutExercise.workout.start)) < %@", until as NSDate)
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, untilPredicate])
        }
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WorkoutExercise.workout?.start, ascending: false)]
        // Fault the past sessions in lazily, so opening a workout with several exercises does not
        // materialize every past instance of each exercise up front on the main thread.
        request.fetchBatchSize = 20
        return request
    }
    
    public class func create(context: NSManagedObjectContext) -> WorkoutExercise {
        let workoutExercise = WorkoutExercise(context: context)
        workoutExercise.uuid = UUID()
        return workoutExercise
    }
    
    public var historyFetchRequest: NSFetchRequest<WorkoutExercise> {
        WorkoutExercise.historyFetchRequest(of: exerciseUuid, until: workout?.start)
    }
    
    // MARK: Derived properties
    
    public func exercise(in exercises: [Exercise]) -> Exercise? {
        ExerciseStore.find(in: exercises, with: exerciseUuid)
    }

    /// For a bodyweight exercise, whether its sets are assisted (bodyweight minus the entered weight)
    /// rather than weighted (bodyweight plus it). Defaults to weighted. Drives the sign of new entries.
    public var assistedValue: Bool {
        get { assisted?.boolValue ?? false }
        set { assisted = newValue as NSNumber }
    }
    
    public var isCompleted: Bool? {
        guard let workoutSets = workoutSets else { return nil }
        return !workoutSets
            .compactMap { $0 as? WorkoutSet }
            .contains { !$0.isCompleted }
    }

    public var numberOfCompletedSets: Int? {
        workoutSets?
            .compactMap { $0 as? WorkoutSet }
            .filter { $0.isCompleted }
            .count
    }

    public var numberOfCompletedRepetitions: Int? {
        workoutSets?
            .compactMap { $0 as? WorkoutSet }
            .reduce(0, { (count, workoutSet) -> Int in
                count + (workoutSet.isCompleted ? Int(workoutSet.repetitionsValue) : 0)
            })
    }

    public func totalCompletedWeight(fallbackBodyweight: Double) -> Double? {
        workoutSets?
            .compactMap { $0 as? WorkoutSet }
            .reduce(0, { (weight, workoutSet) -> Double in
                weight + (workoutSet.isCompleted ? workoutSet.effectiveWeight(fallbackBodyweight: fallbackBodyweight) * Double(workoutSet.repetitionsValue) : 0)
            })
    }
    
    // MARK: - Codable
    private enum CodingKeys: String, CodingKey {
        case uuid
        case exerciseUuid
        case exerciseName
        case comment
        case supersetUUID
        case supersetComment
        case sets
    }

    required convenience public init(from decoder: Decoder) throws {
        guard let contextKey = CodingUserInfoKey.managedObjectContextKey,
            let context = decoder.userInfo[contextKey] as? NSManagedObjectContext,
            let entity = NSEntityDescription.entity(forEntityName: "WorkoutExercise", in: context)
            else {
            throw CodingUserInfoKey.DecodingError.managedObjectContextMissing
        }
        self.init(entity: entity, insertInto: context)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decodeIfPresent(UUID.self, forKey: .uuid) ?? UUID() // make sure we always have an UUID
        exerciseUuid = try container.decodeIfPresent(UUID.self, forKey: .exerciseUuid)
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        // Older exports have no superset id; those exercises decode as ungrouped.
        supersetUUID = try container.decodeIfPresent(UUID.self, forKey: .supersetUUID)
        supersetComment = try container.decodeIfPresent(String.self, forKey: .supersetComment)
        workoutSets = NSOrderedSet(array: try container.decodeIfPresent([WorkoutSet].self, forKey: .sets) ?? [])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid ?? UUID(), forKey: .uuid)
        try container.encodeIfPresent(exerciseUuid, forKey: .exerciseUuid)
        try container.encodeIfPresent(comment, forKey: .comment)
        try container.encodeIfPresent(supersetUUID, forKey: .supersetUUID)
        try container.encodeIfPresent(supersetComment, forKey: .supersetComment)
        try container.encodeIfPresent(workoutSets?.array.compactMap { $0 as? WorkoutSet }, forKey: .sets)
        
        if let exercisesKey = CodingUserInfoKey.exercisesKey,
            let exercises = encoder.userInfo[exercisesKey] as? [Exercise] {
            try container.encodeIfPresent(exercise(in: exercises)?.title, forKey: .exerciseName)
        }
    }
}
