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
