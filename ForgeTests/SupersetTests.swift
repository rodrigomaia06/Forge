//
//  SupersetTests.swift
//  ForgeTests
//
//  Grouping, ordering, and the rest/reorder decisions that supersets depend on.
//

import XCTest
import CoreData
import WorkoutDataKit

final class SupersetTests: XCTestCase {
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext { container.viewContext }

    override func setUp() {
        super.setUp()
        container = setUpInMemoryNSPersistentContainer()
    }

    override func tearDown() {
        context.reset()
        container = nil
        super.tearDown()
    }

    /// A current workout with `count` exercises, in order.
    @discardableResult
    private func makeWorkout(exercises count: Int) -> (Workout, [WorkoutExercise]) {
        let workout = Workout.create(context: context)
        workout.isCurrentWorkout = true
        var exercises: [WorkoutExercise] = []
        for _ in 0..<count {
            let exercise = WorkoutExercise.create(context: context)
            exercise.exerciseUuid = UUID()
            workout.addToWorkoutExercises(exercise)
            exercises.append(exercise)
        }
        try! context.save()
        return (workout, exercises)
    }

    private func orderedExercises(_ workout: Workout) -> [WorkoutExercise] {
        workout.workoutExercises?.array as? [WorkoutExercise] ?? []
    }

    private func slotExercises(_ workout: Workout) -> [[WorkoutExercise]] {
        workout.exerciseSlots.map { $0.exercises }
    }

    func testMakeSupersetSharesIdAndGroupsAdjacent() {
        let (workout, e) = makeWorkout(exercises: 4) // A B C D
        let uuid = workout.makeSuperset(from: [e[1], e[2]])
        XCTAssertNotNil(uuid)
        XCTAssertEqual(e[1].supersetUUID, uuid)
        XCTAssertEqual(e[2].supersetUUID, uuid)
        XCTAssertNil(e[0].supersetUUID)
        XCTAssertNil(e[3].supersetUUID)
        // Already adjacent, so the order is unchanged.
        XCTAssertEqual(orderedExercises(workout), [e[0], e[1], e[2], e[3]])
        XCTAssertEqual(slotExercises(workout), [[e[0]], [e[1], e[2]], [e[3]]])
    }

    func testMakeSupersetPullsNonAdjacentTogetherKeepingPassedOrder() {
        let (workout, e) = makeWorkout(exercises: 4) // A B C D
        // Group B and D, passed as [D, B] so the superset order is D then B.
        workout.makeSuperset(from: [e[3], e[1]])
        // The group lands where the earliest member (B, index 1) was.
        XCTAssertEqual(orderedExercises(workout), [e[0], e[3], e[1], e[2]])
        XCTAssertEqual(slotExercises(workout), [[e[0]], [e[3], e[1]], [e[2]]])
    }

    func testMakeSupersetNeedsTwo() {
        let (workout, e) = makeWorkout(exercises: 2)
        XCTAssertNil(workout.makeSuperset(from: [e[0]]))
        XCTAssertNil(e[0].supersetUUID)
    }

    func testPartnersIndexAndLast() {
        let (workout, e) = makeWorkout(exercises: 3) // A B C
        workout.makeSuperset(from: [e[0], e[1], e[2]])
        XCTAssertEqual(e[0].supersetPartners, [e[0], e[1], e[2]])
        XCTAssertEqual(e[0].supersetIndex, 0)
        XCTAssertEqual(e[2].supersetIndex, 2)
        XCTAssertFalse(e[0].isLastInSuperset)
        XCTAssertTrue(e[2].isLastInSuperset)
    }

    func testRestAndReorderDecisions() {
        let (workout, e) = makeWorkout(exercises: 3) // A B C
        workout.makeSuperset(from: [e[0], e[1]]) // A,B superset; C single

        // Single exercise: rest starts, reorders as normal.
        XCTAssertTrue(e[2].startsRestTimerOnSetCompletion)
        XCTAssertTrue(e[2].reordersBehindLastBegunOnSetCompletion)
        // First in superset: rest holds, does not reorder.
        XCTAssertFalse(e[0].startsRestTimerOnSetCompletion)
        XCTAssertFalse(e[0].reordersBehindLastBegunOnSetCompletion)
        // Last in superset: rest starts, still does not reorder.
        XCTAssertTrue(e[1].startsRestTimerOnSetCompletion)
        XCTAssertFalse(e[1].reordersBehindLastBegunOnSetCompletion)
    }

    func testUngroup() {
        let (workout, e) = makeWorkout(exercises: 3)
        let uuid = workout.makeSuperset(from: [e[0], e[1]])!
        workout.ungroupSuperset(id: uuid)
        XCTAssertNil(e[0].supersetUUID)
        XCTAssertNil(e[1].supersetUUID)
        XCTAssertEqual(slotExercises(workout), [[e[0]], [e[1]], [e[2]]])
    }

    func testNormalizeClearsLoneMemberButKeepsRealGroup() {
        let (workout, e) = makeWorkout(exercises: 3) // A B C
        let group = workout.makeSuperset(from: [e[0], e[1]])!
        // Give C a stale id shared with no one.
        e[2].supersetUUID = UUID()
        workout.normalizeSupersets()
        XCTAssertNil(e[2].supersetUUID)         // lone member cleared
        XCTAssertEqual(e[0].supersetUUID, group) // real group kept
        XCTAssertEqual(e[1].supersetUUID, group)
    }

    func testSupersetNoteSharedAcrossMembersAndClearedOnUngroup() {
        let (workout, e) = makeWorkout(exercises: 3) // A B C
        let uuid = workout.makeSuperset(from: [e[0], e[1]])!
        e[0].setSupersetNote("drop 10% each round")

        // Stored on every member of the group, and on none outside it.
        XCTAssertEqual(e[0].supersetComment, "drop 10% each round")
        XCTAssertEqual(e[1].supersetComment, "drop 10% each round")
        XCTAssertNil(e[2].supersetComment)
        // Readable from any member.
        XCTAssertEqual(e[0].supersetNote, "drop 10% each round")
        XCTAssertEqual(e[1].supersetNote, "drop 10% each round")

        // Ungrouping clears the shared note with the group.
        workout.ungroupSuperset(id: uuid)
        XCTAssertNil(e[0].supersetComment)
        XCTAssertNil(e[1].supersetComment)
        XCTAssertNil(e[0].supersetNote)
    }

    func testSupersetNoteTrimsAndClearsOnEmpty() {
        let (workout, e) = makeWorkout(exercises: 2)
        workout.makeSuperset(from: [e[0], e[1]])
        e[0].setSupersetNote("  spaced  ")
        XCTAssertEqual(e[0].supersetComment, "spaced")
        e[0].setSupersetNote("   ")
        XCTAssertNil(e[0].supersetComment)
        XCTAssertNil(e[1].supersetComment)
    }

    func testAppendedExercisesFormGroupInOrder() {
        // Mirrors add-time: two exercises added together and grouped keep their order as A, B.
        let (workout, e) = makeWorkout(exercises: 2)
        let uuid = workout.makeSuperset(from: [e[0], e[1]])!
        let slots = workout.exerciseSlots
        XCTAssertEqual(slots.count, 1)
        if case let .superset(id, exercises) = slots[0] {
            XCTAssertEqual(id, uuid)
            XCTAssertEqual(exercises, [e[0], e[1]])
        } else {
            XCTFail("expected a superset slot")
        }
    }
}
