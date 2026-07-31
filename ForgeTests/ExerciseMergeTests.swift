//
//  ExerciseMergeTests.swift
//  ForgeTests
//
//  Removed duplicate exercises are merged into the one they duplicated: saved workout and routine
//  references to a removed id are rewritten to the kept id, unrelated references are left alone, and
//  running the merge again is a no-op.
//

import XCTest
import CoreData
import WorkoutDataKit
@testable import Forge

final class ExerciseMergeTests: XCTestCase {
    // Pull Up (Weighted), removed, merged into Pull Up.
    private let removed = UUID(uuidString: "32D30AE5-552D-57E2-BB14-068443BB351A")!
    private let kept = UUID(uuidString: "59185216-6167-4427-AC10-38A3FDA17572")!

    func testRemapsRemovedReferencesAndLeavesOthersAlone() throws {
        let context = setUpInMemoryNSPersistentContainer().viewContext
        let other = UUID() // an unrelated exercise

        let workout = Workout.create(context: context)
        workout.start = Date(timeIntervalSince1970: 1_700_000_000)
        workout.end = Date(timeIntervalSince1970: 1_700_003_600)
        let we = WorkoutExercise.create(context: context); we.exerciseUuid = removed; we.workout = workout
        let untouched = WorkoutExercise.create(context: context); untouched.exerciseUuid = other; untouched.workout = workout
        let routine = WorkoutRoutine.create(context: context)
        let re = WorkoutRoutineExercise.create(context: context); re.exerciseUuid = removed; re.workoutRoutine = routine
        try context.save()

        let changed = try WorkoutDataStorage.remapRenamedExercises(context: context)
        XCTAssertEqual(changed, 2)
        XCTAssertEqual(we.exerciseUuid, kept)
        XCTAssertEqual(re.exerciseUuid, kept)
        XCTAssertEqual(untouched.exerciseUuid, other)

        // Idempotent: nothing left to remap.
        XCTAssertEqual(try WorkoutDataStorage.remapRenamedExercises(context: context), 0)
    }

    func testMovesLegacyBodyweightWeightIntoAddedWeight() throws {
        let context = setUpInMemoryNSPersistentContainer().viewContext
        let pullUp = UUID()
        let workout = Workout.create(context: context)
        workout.start = Date(timeIntervalSince1970: 1_700_000_000)
        workout.end = Date(timeIntervalSince1970: 1_700_003_600)
        let exercise = WorkoutExercise.create(context: context); exercise.exerciseUuid = pullUp; exercise.workout = workout

        // A legacy weighted set (value in weight, addedWeight nil).
        let legacy = WorkoutSet.create(context: context)
        legacy.weightValue = 40; legacy.repetitionsValue = 5; legacy.isCompleted = true; legacy.workoutExercise = exercise
        // An already-migrated set is left alone.
        let migrated = WorkoutSet.create(context: context)
        migrated.addedWeightValue = 10; migrated.weightValue = 0; migrated.repetitionsValue = 5; migrated.isCompleted = true; migrated.workoutExercise = exercise
        try context.save()

        let changed = try WorkoutDataStorage.moveBodyweightWeightToAdded(context: context, exerciseUUIDs: [pullUp])
        XCTAssertEqual(changed, 1)
        XCTAssertEqual(legacy.addedWeightValue, 40) // weight preserved, now weighted
        XCTAssertNil(legacy.weight)
        XCTAssertEqual(migrated.addedWeightValue, 10) // untouched

        // Idempotent.
        XCTAssertEqual(try WorkoutDataStorage.moveBodyweightWeightToAdded(context: context, exerciseUUIDs: [pullUp]), 0)
    }

    func testMappingIsWellFormed() {
        // No id maps to itself, and no kept id is also a removed id (which would chain or loop).
        let map = WorkoutDataStorage.renamedExerciseUUIDs
        XCTAssertEqual(map.count, 11)
        for (removed, kept) in map {
            XCTAssertNotEqual(removed, kept)
            XCTAssertNil(map[kept], "a kept id must not itself be remapped")
        }
    }
}
