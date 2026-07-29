//
//  WorkoutDataExchange.swift
//  Forge
//
//  A small, self-contained JSON format for sharing workout plans and individual workouts between
//  people. Unlike the Core Data models' own Codable conformance, this uses plain value types, so the
//  file carries no store identifiers or routine cross-references. On import every object is created
//  fresh (new UUIDs), so a shared file merges into the database without colliding with existing data.
//
//  This is data-critical code. The round-trip is covered by WorkoutDataExchangeTests.
//

import Foundation
import CoreData
import WorkoutDataKit

enum WorkoutDataExchange {
    /// Bump when the format changes incompatibly. Import refuses a file from a newer version.
    static let formatVersion = 1

    enum ExchangeError: LocalizedError {
        case unsupportedVersion
        case empty

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion: return "This file was made by a newer version of Forge."
            case .empty: return "This file has no workouts or plans to import."
            }
        }
    }

    /// Counts of what was imported, for a plain-language confirmation.
    struct ImportResult {
        let plans: Int
        let routines: Int
        let workouts: Int
    }

    // MARK: File shape

    struct File: Codable {
        var formatVersion: Int
        var plans: [PlanDTO]
        var routines: [RoutineDTO]
        var workouts: [WorkoutDTO]

        init(formatVersion: Int, plans: [PlanDTO] = [], routines: [RoutineDTO] = [], workouts: [WorkoutDTO] = []) {
            self.formatVersion = formatVersion
            self.plans = plans
            self.routines = routines
            self.workouts = workouts
        }

        // Tolerant decoding: a file may carry any subset (only plans, only a routine, only workouts).
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            formatVersion = try container.decode(Int.self, forKey: .formatVersion)
            plans = try container.decodeIfPresent([PlanDTO].self, forKey: .plans) ?? []
            routines = try container.decodeIfPresent([RoutineDTO].self, forKey: .routines) ?? []
            workouts = try container.decodeIfPresent([WorkoutDTO].self, forKey: .workouts) ?? []
        }
    }

    struct PlanDTO: Codable {
        var title: String?
        var routines: [RoutineDTO]
    }

    struct RoutineDTO: Codable {
        var title: String?
        var comment: String?
        var attributes: [String: String]?
        var exercises: [RoutineExerciseDTO]
    }

    struct RoutineExerciseDTO: Codable {
        var exerciseUuid: UUID
        var comment: String?
        var sets: [RoutineSetDTO]
    }

    struct RoutineSetDTO: Codable {
        var minReps: Int16?
        var maxReps: Int16?
        var tag: String?
        var comment: String?
    }

    struct WorkoutDTO: Codable {
        var title: String?
        var comment: String?
        var start: Date?
        var end: Date?
        var attributes: [String: String]?
        var exercises: [WorkoutExerciseDTO]
        // Optional link to a routine (and its plan) imported in the same file. When set and no explicit
        // title is given, the workout is named from the routine, so the "show plan in name" setting
        // applies to it like any routine-started workout.
        var plan: String?
        var routine: String?
    }

    struct WorkoutExerciseDTO: Codable {
        var exerciseUuid: UUID
        var comment: String?
        var sets: [WorkoutSetDTO]
    }

    struct WorkoutSetDTO: Codable {
        var weight: Double?
        var reps: Int16?
        var isCompleted: Bool
        var tag: String?
        var rpe: Double?
        var comment: String?
        var minTargetReps: Int16?
        var maxTargetReps: Int16?
    }

    // MARK: Export

    static func export(plans: [WorkoutPlan] = [], routines: [WorkoutRoutine] = [], workouts: [Workout] = []) throws -> Data {
        let file = File(formatVersion: formatVersion, plans: plans.map(dto(from:)), routines: routines.map(routineDTO(from:)), workouts: workouts.map(dto(from:)))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(file)
    }

    private static func dto(from plan: WorkoutPlan) -> PlanDTO {
        PlanDTO(title: plan.title, routines: orderedRoutines(plan).map(routineDTO(from:)))
    }

    private static func routineDTO(from routine: WorkoutRoutine) -> RoutineDTO {
        RoutineDTO(
            title: routine.title,
            comment: routine.comment,
            attributes: routine.customAttributes.isEmpty ? nil : routine.customAttributes,
            exercises: orderedRoutineExercises(routine).map { exercise in
                RoutineExerciseDTO(
                    exerciseUuid: exercise.exerciseUuid ?? UUID(),
                    comment: exercise.comment,
                    sets: orderedRoutineSets(exercise).map { set in
                        RoutineSetDTO(minReps: set.minRepetitionsValue, maxReps: set.maxRepetitionsValue, tag: set.tagValue?.rawValue, comment: set.comment)
                    }
                )
            }
        )
    }

    private static func dto(from workout: Workout) -> WorkoutDTO {
        WorkoutDTO(
            title: workout.title,
            comment: workout.comment,
            start: workout.start,
            end: workout.end,
            attributes: workout.customAttributes.isEmpty ? nil : workout.customAttributes,
            exercises: orderedWorkoutExercises(workout).map { exercise in
                WorkoutExerciseDTO(
                    exerciseUuid: exercise.exerciseUuid ?? UUID(),
                    comment: exercise.comment,
                    sets: orderedWorkoutSets(exercise).map { set in
                        WorkoutSetDTO(
                            weight: set.weight?.doubleValue,
                            reps: set.repetitions?.int16Value,
                            isCompleted: set.isCompleted,
                            tag: set.tagValue?.rawValue,
                            rpe: set.rpeValue,
                            comment: set.comment,
                            minTargetReps: set.minTargetRepetitionsValue,
                            maxTargetReps: set.maxTargetRepetitionsValue
                        )
                    }
                )
            },
            plan: workout.workoutRoutine?.workoutPlan?.title,
            routine: workout.workoutRoutine?.title
        )
    }

    // MARK: Inspect

    /// Decode-only: counts what a file would add, for a confirmation shown before importing. Does not
    /// touch the store. Throws the same version/empty errors as import.
    static func summary(_ data: Data) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(File.self, from: data)
        guard file.formatVersion <= formatVersion else { throw ExchangeError.unsupportedVersion }
        guard !file.plans.isEmpty || !file.routines.isEmpty || !file.workouts.isEmpty else { throw ExchangeError.empty }
        return ImportResult(plans: file.plans.count, routines: file.routines.count, workouts: file.workouts.count)
    }

    // MARK: Import

    /// Decodes the file and inserts fresh copies into `context`, then saves. Returns what was added.
    /// Workouts (past history) are only imported when `includeWorkouts` is true; the ordinary share
    /// import leaves them out so a shared file can only add plans and routines, never inject history.
    @discardableResult
    static func `import`(_ data: Data, into context: NSManagedObjectContext, includeWorkouts: Bool = false) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(File.self, from: data)
        guard file.formatVersion <= formatVersion else { throw ExchangeError.unsupportedVersion }
        let workouts = includeWorkouts ? file.workouts : []
        guard !file.plans.isEmpty || !file.routines.isEmpty || !workouts.isEmpty else { throw ExchangeError.empty }

        // Routines imported in this file, keyed by plan+routine title, so a workout can link to one.
        var routinesByName: [String: WorkoutRoutine] = [:]
        for planDTO in file.plans {
            let plan = WorkoutPlan.create(context: context)
            plan.title = planDTO.title
            for routineDTO in planDTO.routines {
                let routine = makeRoutine(routineDTO, plan: plan, into: context)
                routinesByName[routineKey(plan: planDTO.title, routine: routineDTO.title)] = routine
            }
        }
        for routineDTO in file.routines {
            let routine = makeRoutine(routineDTO, plan: nil, into: context)
            routinesByName[routineKey(plan: nil, routine: routineDTO.title)] = routine
        }
        for workoutDTO in workouts {
            let workout = insert(workoutDTO, into: context)
            if let routineTitle = workoutDTO.routine {
                workout.workoutRoutine = routinesByName[routineKey(plan: workoutDTO.plan, routine: routineTitle)]
                    ?? routinesByName[routineKey(plan: nil, routine: routineTitle)]
            }
        }

        try context.save()
        return ImportResult(plans: file.plans.count, routines: file.routines.count, workouts: workouts.count)
    }

    private static func routineKey(plan: String?, routine: String?) -> String {
        (plan ?? "") + "\u{1}" + (routine ?? "")
    }

    // Ordered relationships are built by setting the to-one inverse on each child (which appends it in
    // order). Assigning an NSOrderedSet on the parent does not maintain the inverse, so a required
    // inverse would be left nil and fail validation on save.
    @discardableResult
    private static func makeRoutine(_ dto: RoutineDTO, plan: WorkoutPlan?, into context: NSManagedObjectContext) -> WorkoutRoutine {
        let routine = WorkoutRoutine.create(context: context)
        routine.title = dto.title
        routine.comment = dto.comment
        if let attributes = dto.attributes { routine.customAttributes = attributes }
        routine.workoutPlan = plan
        for exerciseDTO in dto.exercises {
            let exercise = WorkoutRoutineExercise.create(context: context)
            exercise.exerciseUuid = exerciseDTO.exerciseUuid
            exercise.comment = exerciseDTO.comment
            exercise.workoutRoutine = routine
            for setDTO in exerciseDTO.sets {
                let set = WorkoutRoutineSet.create(context: context)
                set.minRepetitionsValue = setDTO.minReps
                set.maxRepetitionsValue = setDTO.maxReps
                if let tag = setDTO.tag { set.tagValue = WorkoutSetTag(rawValue: tag) }
                set.comment = setDTO.comment
                set.workoutRoutineExercise = exercise
            }
        }
        return routine
    }

    @discardableResult
    private static func insert(_ dto: WorkoutDTO, into context: NSManagedObjectContext) -> Workout {
        let workout = Workout.create(context: context)
        workout.title = dto.title
        workout.comment = dto.comment
        // A shared workout is a finished record, never the current workout; give it a start if missing
        // so it validates, and an end no earlier than the start.
        workout.start = dto.start ?? dto.end
        workout.end = dto.end ?? dto.start
        workout.isCurrentWorkout = false
        if let attributes = dto.attributes { workout.customAttributes = attributes }
        for exerciseDTO in dto.exercises {
            let exercise = WorkoutExercise.create(context: context)
            exercise.exerciseUuid = exerciseDTO.exerciseUuid
            exercise.comment = exerciseDTO.comment
            exercise.workout = workout
            for setDTO in exerciseDTO.sets {
                let set = WorkoutSet.create(context: context)
                if let weight = setDTO.weight { set.weightValue = weight }
                if let reps = setDTO.reps { set.repetitionsValue = reps }
                set.isCompleted = setDTO.isCompleted
                if let tag = setDTO.tag { set.tagValue = WorkoutSetTag(rawValue: tag) }
                if let rpe = setDTO.rpe { set.rpeValue = rpe }
                set.comment = setDTO.comment
                set.minTargetRepetitionsValue = setDTO.minTargetReps
                set.maxTargetRepetitionsValue = setDTO.maxTargetReps
                set.workoutExercise = exercise
            }
        }
        return workout
    }

    // MARK: Ordered helpers

    private static func orderedRoutines(_ plan: WorkoutPlan) -> [WorkoutRoutine] {
        plan.workoutRoutines?.array as? [WorkoutRoutine] ?? []
    }
    private static func orderedRoutineExercises(_ routine: WorkoutRoutine) -> [WorkoutRoutineExercise] {
        routine.workoutRoutineExercises?.array as? [WorkoutRoutineExercise] ?? []
    }
    private static func orderedRoutineSets(_ exercise: WorkoutRoutineExercise) -> [WorkoutRoutineSet] {
        exercise.workoutRoutineSets?.array as? [WorkoutRoutineSet] ?? []
    }
    private static func orderedWorkoutExercises(_ workout: Workout) -> [WorkoutExercise] {
        workout.workoutExercises?.array as? [WorkoutExercise] ?? []
    }
    private static func orderedWorkoutSets(_ exercise: WorkoutExercise) -> [WorkoutSet] {
        exercise.workoutSets?.array as? [WorkoutSet] ?? []
    }
}
