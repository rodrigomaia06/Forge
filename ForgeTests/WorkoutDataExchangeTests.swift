//
//  WorkoutDataExchangeTests.swift
//  ForgeTests
//
//  Round-trip coverage for the JSON share format: a plan and a workout survive export and import,
//  and the imported copy gets fresh store identifiers so it never collides with existing data.
//

import XCTest
import CoreData
@testable import Forge
import WorkoutDataKit

final class WorkoutDataExchangeTests: XCTestCase {
    var container: NSPersistentContainer!

    override func setUp() {
        super.setUp()
        container = setUpInMemoryNSPersistentContainer()
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    private func fetch<T: NSManagedObject>(_ type: T.Type, _ name: String, in context: NSManagedObjectContext) throws -> [T] {
        try context.fetch(NSFetchRequest<T>(entityName: name))
    }

    func testPlanRoundTrip() throws {
        let context = container.viewContext

        let plan = WorkoutPlan.create(context: context)
        plan.title = "Push Pull Legs"
        let routine = WorkoutRoutine.create(context: context)
        routine.title = "Push"
        routine.comment = "Chest day"
        routine.customAttributes = ["Location": "Home"]
        routine.workoutPlan = plan
        let exerciseUuid = UUID()
        let exercise = WorkoutRoutineExercise.create(context: context)
        exercise.exerciseUuid = exerciseUuid
        exercise.assistedValue = true
        exercise.singleRepTargetValue = true
        exercise.workoutRoutine = routine
        let set = WorkoutRoutineSet.create(context: context)
        set.minRepetitionsValue = 6
        set.maxRepetitionsValue = 8
        set.tagValue = .dropSet
        set.workoutRoutineExercise = exercise
        try context.save()

        let data = try WorkoutDataExchange.export(plans: [plan])

        let other = setUpInMemoryNSPersistentContainer().viewContext
        let result = try WorkoutDataExchange.import(data, into: other, includeWorkouts: true)
        XCTAssertEqual(result.plans, 1)
        XCTAssertEqual(result.workouts, 0)

        let plans = try fetch(WorkoutPlan.self, "WorkoutPlan", in: other)
        XCTAssertEqual(plans.count, 1)
        let importedPlan = plans[0]
        XCTAssertEqual(importedPlan.title, "Push Pull Legs")
        // Fresh identity so it merges without collision.
        XCTAssertNotEqual(importedPlan.uuid, plan.uuid)

        let routines = importedPlan.workoutRoutines?.array as? [WorkoutRoutine] ?? []
        XCTAssertEqual(routines.count, 1)
        XCTAssertEqual(routines[0].title, "Push")
        XCTAssertEqual(routines[0].comment, "Chest day")
        XCTAssertEqual(routines[0].customAttributes["Location"], "Home")

        let exercises = routines[0].workoutRoutineExercises?.array as? [WorkoutRoutineExercise] ?? []
        XCTAssertEqual(exercises.count, 1)
        // The exercise reference is a stable definition id and is preserved.
        XCTAssertEqual(exercises[0].exerciseUuid, exerciseUuid)
        // The bodyweight-assisted and single-rep-target flags survive the round trip.
        XCTAssertTrue(exercises[0].assistedValue)
        XCTAssertTrue(exercises[0].singleRepTargetValue)

        let sets = exercises[0].workoutRoutineSets?.array as? [WorkoutRoutineSet] ?? []
        XCTAssertEqual(sets.count, 1)
        XCTAssertEqual(sets[0].minRepetitionsValue, 6)
        XCTAssertEqual(sets[0].maxRepetitionsValue, 8)
        XCTAssertEqual(sets[0].tagValue, .dropSet)
    }

    func testStandaloneRoutineRoundTrip() throws {
        let context = container.viewContext

        let routine = WorkoutRoutine.create(context: context)
        routine.title = "Push"
        let exercise = WorkoutRoutineExercise.create(context: context)
        exercise.exerciseUuid = UUID()
        exercise.workoutRoutine = routine
        let set = WorkoutRoutineSet.create(context: context)
        set.minRepetitionsValue = 8
        set.maxRepetitionsValue = 12
        set.workoutRoutineExercise = exercise
        try context.save()

        let data = try WorkoutDataExchange.export(routines: [routine])

        let other = setUpInMemoryNSPersistentContainer().viewContext
        let result = try WorkoutDataExchange.import(data, into: other, includeWorkouts: true)
        XCTAssertEqual(result.routines, 1)
        XCTAssertEqual(result.plans, 0)

        let routines = try fetch(WorkoutRoutine.self, "WorkoutRoutine", in: other)
        XCTAssertEqual(routines.count, 1)
        XCTAssertEqual(routines[0].title, "Push")
        // Imported as a standalone routine (no plan).
        XCTAssertNil(routines[0].workoutPlan)
        let sets = (routines[0].workoutRoutineExercises?.array as? [WorkoutRoutineExercise] ?? [])
            .flatMap { $0.workoutRoutineSets?.array as? [WorkoutRoutineSet] ?? [] }
        XCTAssertEqual(sets.first?.minRepetitionsValue, 8)
        XCTAssertEqual(sets.first?.maxRepetitionsValue, 12)
    }

    func testWorkoutRoundTrip() throws {
        let context = container.viewContext

        let workout = Workout.create(context: context)
        workout.title = "Morning session"
        workout.start = Date(timeIntervalSince1970: 1_700_000_000)
        workout.end = Date(timeIntervalSince1970: 1_700_003_600)
        workout.customAttributes = ["Mood": "Good"]
        let exerciseUuid = UUID()
        let exercise = WorkoutExercise.create(context: context)
        exercise.exerciseUuid = exerciseUuid
        exercise.workout = workout
        let set = WorkoutSet.create(context: context)
        set.weightValue = 60
        set.repetitionsValue = 5
        set.isCompleted = true
        set.workoutExercise = exercise
        try context.save()

        let data = try WorkoutDataExchange.export(workouts: [workout])

        let other = setUpInMemoryNSPersistentContainer().viewContext
        let result = try WorkoutDataExchange.import(data, into: other, includeWorkouts: true)
        XCTAssertEqual(result.workouts, 1)

        let workouts = try fetch(Workout.self, "Workout", in: other)
        XCTAssertEqual(workouts.count, 1)
        let imported = workouts[0]
        XCTAssertEqual(imported.title, "Morning session")
        XCTAssertFalse(imported.isCurrentWorkout)
        XCTAssertEqual(imported.customAttributes["Mood"], "Good")
        XCTAssertNotEqual(imported.uuid, workout.uuid)

        let sets = (imported.workoutExercises?.array as? [WorkoutExercise] ?? [])
            .flatMap { $0.workoutSets?.array as? [WorkoutSet] ?? [] }
        XCTAssertEqual(sets.count, 1)
        XCTAssertEqual(sets[0].weightValue, 60)
        XCTAssertEqual(sets[0].repetitionsValue, 5)
        XCTAssertTrue(sets[0].isCompleted)
    }

    func testWorkoutSupersetRoundTrip() throws {
        let context = container.viewContext

        let workout = Workout.create(context: context)
        workout.title = "Push day"
        workout.start = Date(timeIntervalSince1970: 1_700_000_000)
        workout.end = Date(timeIntervalSince1970: 1_700_003_600)
        var exercises: [WorkoutExercise] = []
        for _ in 0..<3 {
            let exercise = WorkoutExercise.create(context: context)
            exercise.exerciseUuid = UUID()
            exercise.workout = workout
            let set = WorkoutSet.create(context: context)
            set.weightValue = 50
            set.repetitionsValue = 5
            set.isCompleted = true
            set.workoutExercise = exercise
            exercises.append(exercise)
        }
        // Group the first two into a superset, with a shared note.
        workout.makeSuperset(from: [exercises[0], exercises[1]])
        exercises[0].setSupersetNote("drop 10% each round")
        try context.save()

        let data = try WorkoutDataExchange.export(workouts: [workout])
        let other = setUpInMemoryNSPersistentContainer().viewContext
        _ = try WorkoutDataExchange.import(data, into: other, includeWorkouts: true)

        let imported = try fetch(Workout.self, "Workout", in: other)[0]
        let importedExercises = imported.workoutExercises?.array as? [WorkoutExercise] ?? []
        XCTAssertEqual(importedExercises.count, 3)
        XCTAssertNotNil(importedExercises[0].supersetUUID)
        XCTAssertEqual(importedExercises[0].supersetUUID, importedExercises[1].supersetUUID)
        XCTAssertNil(importedExercises[2].supersetUUID)
        // The group id is minted fresh on import, not carried from the source.
        XCTAssertNotEqual(importedExercises[0].supersetUUID, exercises[0].supersetUUID)
        // The shared note survives, on each member of the group.
        XCTAssertEqual(importedExercises[0].supersetComment, "drop 10% each round")
        XCTAssertEqual(importedExercises[1].supersetComment, "drop 10% each round")
    }

    func testRoutineSupersetRoundTrip() throws {
        let context = container.viewContext

        let plan = WorkoutPlan.create(context: context)
        plan.title = "Upper lower"
        let routine = WorkoutRoutine.create(context: context)
        routine.title = "Upper"
        routine.workoutPlan = plan
        var exercises: [WorkoutRoutineExercise] = []
        for _ in 0..<3 {
            let exercise = WorkoutRoutineExercise.create(context: context)
            exercise.exerciseUuid = UUID()
            exercise.workoutRoutine = routine
            exercises.append(exercise)
        }
        routine.makeSuperset(from: [exercises[1], exercises[2]])
        try context.save()

        let data = try WorkoutDataExchange.export(plans: [plan])
        let other = setUpInMemoryNSPersistentContainer().viewContext
        _ = try WorkoutDataExchange.import(data, into: other, includeWorkouts: true)

        let importedPlan = try fetch(WorkoutPlan.self, "WorkoutPlan", in: other)[0]
        let importedRoutine = (importedPlan.workoutRoutines?.array as? [WorkoutRoutine] ?? [])[0]
        let re = importedRoutine.workoutRoutineExercises?.array as? [WorkoutRoutineExercise] ?? []
        XCTAssertEqual(re.count, 3)
        XCTAssertNil(re[0].supersetUUID)
        XCTAssertNotNil(re[1].supersetUUID)
        XCTAssertEqual(re[1].supersetUUID, re[2].supersetUUID)
    }

    func testBodyweightSetRoundTrip() throws {
        let context = container.viewContext
        let workout = Workout.create(context: context)
        workout.start = Date(timeIntervalSince1970: 1_700_000_000)
        workout.end = Date(timeIntervalSince1970: 1_700_003_600)
        workout.bodyweightValue = 80 // frozen bodyweight for this session
        let exercise = WorkoutExercise.create(context: context)
        exercise.exerciseUuid = UUID()
        exercise.workout = workout
        let set = WorkoutSet.create(context: context)
        set.addedWeightValue = 20 // weighted pull-up
        set.repetitionsValue = 5
        set.isCompleted = true
        set.workoutExercise = exercise
        try context.save()

        let data = try WorkoutDataExchange.export(workouts: [workout])
        let other = setUpInMemoryNSPersistentContainer().viewContext
        _ = try WorkoutDataExchange.import(data, into: other, includeWorkouts: true)

        let imported = try fetch(Workout.self, "Workout", in: other)[0]
        XCTAssertEqual(imported.bodyweightValue, 80) // the frozen bodyweight survives the round trip
        let importedSet = ((imported.workoutExercises?.array as? [WorkoutExercise] ?? [])
            .flatMap { $0.workoutSets?.array as? [WorkoutSet] ?? [] })[0]
        XCTAssertEqual(importedSet.addedWeightValue, 20)
        XCTAssertTrue(importedSet.isBodyweight)
    }

    func testRejectsNewerFormatVersion() throws {
        let json = "{\"formatVersion\": 9999, \"plans\": [], \"workouts\": []}".data(using: .utf8)!
        XCTAssertThrowsError(try WorkoutDataExchange.import(json, into: container.viewContext))
    }
}
