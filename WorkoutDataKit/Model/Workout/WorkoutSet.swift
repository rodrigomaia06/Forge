//
//  WorkoutSet.swift
//  Rhino Fit
//
//  Created by Karim Abou Zeid on 14.02.18.
//  Copyright © 2018 Karim Abou Zeid Software. All rights reserved.
//

import CoreData
import Combine

extension WorkoutSet {
    // WorkoutSet already conforms to Identifiable via Core Data's generated properties.
    /// Identity for SwiftUI, from the uuid rather than the objectID.
    ///
    /// A newly inserted object has a temporary objectID that Core Data replaces with a permanent one the
    /// next time the context saves. Keyed on that, every save gave a set or exercise created during the
    /// workout a brand new identity: SwiftUI tore the row down and built a fresh one, and a text field
    /// being edited inside it was destroyed while it was still first responder. That leaves the keyboard
    /// up with nothing behind it. The uuid is assigned at creation and never changes.
    public var id: String { uuid?.uuidString ?? objectID.uriRepresentation().absoluteString }
}

public class WorkoutSet: NSManagedObject, Codable {
    public static var MAX_REPETITIONS: Int16 = 9999
    public static var MAX_WEIGHT: Double = 99999
    
    public class func create(context: NSManagedObjectContext) -> WorkoutSet {
        let workoutSet = WorkoutSet(context: context)
        workoutSet.uuid = UUID()
        return workoutSet
    }
    
    // MARK: Normalized properties
    
    public var weightValue: Double {
        get {
            weight?.doubleValue ?? 0
        }
        set {
            weight = newValue as NSNumber
        }
    }
    
    public var repetitionsValue: Int16 {
        get {
            repetitions?.int16Value ?? 0
        }
        set {
            repetitions = newValue as NSNumber
        }
    }
    
    public var minTargetRepetitionsValue: Int16? {
        get {
            minTargetRepetitions?.int16Value
        }
        set {
            minTargetRepetitions = newValue as NSNumber?
        }
    }
    
    public var maxTargetRepetitionsValue: Int16? {
        get {
            maxTargetRepetitions?.int16Value
        }
        set {
            maxTargetRepetitions = newValue as NSNumber?
        }
    }
    
    public var tagValue: WorkoutSetTag? {
        get {
            WorkoutSetTag(rawValue: tag ?? "")
        }
        set {
            tag = newValue?.rawValue
        }
    }
    
    public var rpeValue: Double? {
        get {
            RPE.allowedValues.contains(rpe) ? rpe : nil
        }
        set {
            let newValue = newValue ?? 0
            rpe = RPE.allowedValues.contains(newValue) ? newValue : 0
        }
    }

    /// Planned target weight for this set (nil = no target). In kilograms, like `weight`.
    public var targetWeightValue: Double? {
        get {
            targetWeight?.doubleValue
        }
        set {
            targetWeight = newValue as NSNumber?
        }
    }

    /// Planned target RPE for this set (nil = no target).
    public var targetRpeValue: Double? {
        get {
            guard let value = targetRpe?.doubleValue, RPE.allowedValues.contains(value) else { return nil }
            return value
        }
        set {
            if let newValue = newValue, RPE.allowedValues.contains(newValue) {
                targetRpe = newValue as NSNumber
            } else {
                targetRpe = nil
            }
        }
    }

    /// The added or assisted weight for a bodyweight set, in kilograms (may be zero or negative). Nil for a
    /// normal set. Setting a value marks the set as bodyweight; setting nil makes it a normal set again.
    public var addedWeightValue: Double? {
        get { addedWeight?.doubleValue }
        set { addedWeight = newValue as NSNumber? }
    }

    /// True when this set is logged as bodyweight: its load is the user's bodyweight plus the added or
    /// assisted weight, rather than an absolute weight. A bodyweight exercise always stores addedWeight
    /// (zero for a pure bodyweight set), which is what distinguishes it from a normal weighted set.
    public var isBodyweight: Bool { addedWeight != nil }

    /// The effective load in kilograms used for stats: for a bodyweight set, the bodyweight plus the added
    /// (+) or assisted (-) weight; otherwise the absolute weight. The bodyweight is the value frozen on the
    /// set's workout when it finished; `fallbackBodyweight` (the current setting) is used only while a
    /// workout is still in progress, before its bodyweight has been captured.
    public func effectiveWeight(fallbackBodyweight: Double) -> Double {
        guard isBodyweight else { return weightValue }
        let bodyweight = workoutExercise?.workout?.bodyweightValue ?? fallbackBodyweight
        return bodyweight + (addedWeight?.doubleValue ?? 0)
    }

    // MARK: Derived properties

    public func estimatedOneRepMax(maxReps: Int, fallbackBodyweight: Double) -> Double? {
        guard repetitionsValue > 0 && repetitionsValue <= maxReps else { return nil }
        assert(repetitionsValue < 37) // formula doesn't work for 37+ reps
        return effectiveWeight(fallbackBodyweight: fallbackBodyweight) * (36 / (37 - Double(repetitionsValue))) // Brzycki 1RM formula
    }

    public var isPersonalRecord: Bool? {
        guard let weight = weight else { return nil }
        guard let repetitions = repetitions else { return nil }
        guard repetitions.intValue > 0 else { return false }
        guard let start = workoutExercise?.workout?.start else { return nil }
        guard let exerciseUuid = workoutExercise?.exerciseUuid else { return nil }

        let previousSetsRequest: NSFetchRequest<WorkoutSet> = WorkoutSet.fetchRequest()
        let previousSetsPredicate = NSPredicate(format:
            "\(#keyPath(WorkoutSet.workoutExercise.exerciseUuid)) == %@ AND \(#keyPath(WorkoutSet.isCompleted)) == %@ AND \(#keyPath(WorkoutSet.workoutExercise.workout.start)) < %@",
            exerciseUuid as CVarArg, true as NSNumber, start as NSDate
        )
        previousSetsRequest.predicate = previousSetsPredicate
        guard let numberOfPreviousSets = try? managedObjectContext?.count(for: previousSetsRequest) else { return nil }
        if numberOfPreviousSets == 0 { return false } // if there was no set for this exercise in a prior workout, we consider no set as a PR

        let betterOrEqualPreviousSetsRequest: NSFetchRequest<WorkoutSet> = WorkoutSet.fetchRequest()
        betterOrEqualPreviousSetsRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates:
            [
                previousSetsPredicate,
                NSPredicate(format: "\(#keyPath(WorkoutSet.weight)) >= %@ AND \(#keyPath(WorkoutSet.repetitions)) >= %@", weight, repetitions)
            ]
        )
        guard let numberOfBetterOrEqualPreviousSets = try? managedObjectContext?.count(for: betterOrEqualPreviousSetsRequest) else { return nil }
        if numberOfBetterOrEqualPreviousSets > 0 { return false } // there are better sets
        
        guard let index = workoutExercise?.workoutSets?.index(of: self), index != NSNotFound else { return nil }
        guard let numberOfBetterOrEqualPreviousSetsInCurrentWorkout = (workoutExercise?.workoutSets?.array[0..<index]
            .compactMap { $0 as? WorkoutSet }
            .filter { $0.weightValue >= weightValue && $0.repetitionsValue >= repetitionsValue }
            .count)
            else { return nil }
        return numberOfBetterOrEqualPreviousSetsInCurrentWorkout == 0
    }
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case uuid
        case repetitions
        case minTargetRepetitions
        case maxTargetRepetitions
        case weight
        case addedWeight
        case targetWeight
        case rpe
        case targetRpe
        case tag
        case comment
    }
    
    required convenience public init(from decoder: Decoder) throws {
        guard let contextKey = CodingUserInfoKey.managedObjectContextKey,
            let context = decoder.userInfo[contextKey] as? NSManagedObjectContext,
            let entity = NSEntityDescription.entity(forEntityName: "WorkoutSet", in: context)
            else {
            throw CodingUserInfoKey.DecodingError.managedObjectContextMissing
        }
        self.init(entity: entity, insertInto: context)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decodeIfPresent(UUID.self, forKey: .uuid) ?? UUID() // make sure we always have an UUID
        repetitionsValue = try container.decode(Int16.self, forKey: .repetitions)
        weightValue = try container.decode(Double.self, forKey: .weight)
        // Older exports have no addedWeight; those sets decode as normal (non-bodyweight) sets.
        addedWeightValue = try container.decodeIfPresent(Double.self, forKey: .addedWeight)
        rpeValue = try container.decodeIfPresent(Double.self, forKey: .rpe)
        tagValue = WorkoutSetTag(rawValue: try container.decodeIfPresent(String.self, forKey: .tag) ?? "")
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        minTargetRepetitionsValue = try container.decodeIfPresent(Int16.self, forKey: .minTargetRepetitions)
        maxTargetRepetitionsValue = try container.decodeIfPresent(Int16.self, forKey: .maxTargetRepetitions)
        targetWeightValue = try container.decodeIfPresent(Double.self, forKey: .targetWeight)
        targetRpeValue = try container.decodeIfPresent(Double.self, forKey: .targetRpe)
        isCompleted = true
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid ?? UUID(), forKey: .uuid)
        try container.encode(repetitionsValue, forKey: .repetitions)
        try container.encode(weightValue, forKey: .weight)
        try container.encodeIfPresent(addedWeightValue, forKey: .addedWeight)
        try container.encodeIfPresent(rpeValue, forKey: .rpe)
        try container.encodeIfPresent(tagValue?.rawValue, forKey: .tag)
        try container.encodeIfPresent(comment, forKey: .comment)
        try container.encodeIfPresent(minTargetRepetitionsValue, forKey: .minTargetRepetitions)
        try container.encodeIfPresent(maxTargetRepetitionsValue, forKey: .maxTargetRepetitions)
        try container.encodeIfPresent(targetWeightValue, forKey: .targetWeight)
        try container.encodeIfPresent(targetRpeValue, forKey: .targetRpe)
    }
}

// MARK: Display

extension WorkoutSet {
    public func displayTitle(unit: UnitMass, formatter: MeasurementFormatter) -> String {
        let reps = " × \(repetitionsValue)"
        // A bodyweight set reads as the added (+) or assisted (-) weight, or BW for a pure rep.
        if let added = addedWeight?.doubleValue {
            guard added != 0 else { return "BW" + reps }
            let magnitude = formatter.string(from: Measurement(value: abs(added), unit: UnitMass.kilograms).converted(to: unit))
            return "\(added > 0 ? "+" : "-")\(magnitude)" + reps
        }
        return formatter.string(from: Measurement(value: weightValue, unit: UnitMass.kilograms).converted(to: unit)) + reps
    }
    
    public func logTitle(unit: UnitMass, formatter: MeasurementFormatter) -> String {
        let title = displayTitle(unit: unit, formatter: formatter)
        guard let tag = tagValue?.title.capitalized, !tag.isEmpty else { return title }
        return title + " (\(tag))"
    }
}

// MARK: Validation

extension WorkoutSet {
    override public func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateConsistency()
    }
    
    override public func validateForInsert() throws {
        try super.validateForInsert()
        try validateConsistency()
    }
    
    func validateConsistency() throws {
        if !isCompleted, let workout = workoutExercise?.workout, !workout.isCurrentWorkout {
            throw error(code: 1, message: "The set is not completed eventhough its workout is not the current workout.")
        }
    }
    
    private func error(code: Int, message: String) -> NSError {
        NSError(domain: "WORKOUT_SET_ERROR_DOMAIN", code: code, userInfo: [NSLocalizedFailureReasonErrorKey: message, NSValidationObjectErrorKey: self])
    }
}
