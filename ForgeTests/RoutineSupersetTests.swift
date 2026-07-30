//
//  RoutineSupersetTests.swift
//  ForgeTests
//
//  Superset grouping on routines, and carrying grouping across routine <-> workout copies. Data integrity
//  is the point: a group must survive starting a workout, updating a routine, and duplicating.
//

import XCTest
import CoreData
import WorkoutDataKit

final class RoutineSupersetTests: XCTestCase {
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

    private func makeRoutine(exercises count: Int) -> (WorkoutRoutine, [WorkoutRoutineExercise]) {
        let routine = WorkoutRoutine.create(context: context)
        var exercises: [WorkoutRoutineExercise] = []
        for _ in 0..<count {
            let exercise = WorkoutRoutineExercise.create(context: context)
            exercise.exerciseUuid = UUID()
            exercise.workoutRoutine = routine
            exercises.append(exercise)
        }
        try! context.save()
        return (routine, exercises)
    }

    private func makeCurrentWorkout(exercises count: Int) -> (Workout, [WorkoutExercise]) {
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

    private func ordered(_ workout: Workout) -> [WorkoutExercise] {
        workout.workoutExercises?.array as? [WorkoutExercise] ?? []
    }

    private func ordered(_ routine: WorkoutRoutine) -> [WorkoutRoutineExercise] {
        routine.workoutRoutineExercises?.array as? [WorkoutRoutineExercise] ?? []
    }

    // MARK: routine grouping

    func testRoutineMakeSupersetAndLabels() {
        let (routine, e) = makeRoutine(exercises: 3)
        let uuid = routine.makeSuperset(from: [e[0], e[1]])
        XCTAssertNotNil(uuid)
        XCTAssertEqual(e[0].supersetUUID, e[1].supersetUUID)
        XCTAssertNil(e[2].supersetUUID)
        XCTAssertEqual(e[0].supersetLabel, "A")
        XCTAssertEqual(e[1].supersetLabel, "B")
        XCTAssertNil(e[2].supersetLabel)
        XCTAssertEqual(routine.exerciseSlots.map { $0.exercises }, [[e[0], e[1]], [e[2]]])
    }

    func testRoutineSupersetNoteSharedAndCleared() {
        let (routine, e) = makeRoutine(exercises: 3)
        let uuid = routine.makeSuperset(from: [e[0], e[1]])!
        e[0].setSupersetNote("tempo 3-1-1")
        XCTAssertEqual(e[1].supersetComment, "tempo 3-1-1")
        XCTAssertNil(e[2].supersetComment)
        XCTAssertEqual(e[1].supersetNote, "tempo 3-1-1")
        routine.ungroupSuperset(id: uuid)
        XCTAssertNil(e[0].supersetComment)
    }

    // MARK: routine -> workout

    func testCreateWorkoutCarriesGroupingWithFreshIds() {
        let (routine, e) = makeRoutine(exercises: 3)
        let routineGroup = routine.makeSuperset(from: [e[0], e[1]])!

        let workout = routine.createWorkout(context: context)
        let we = ordered(workout)
        XCTAssertEqual(we.count, 3)
        XCTAssertNotNil(we[0].supersetUUID)
        XCTAssertEqual(we[0].supersetUUID, we[1].supersetUUID)
        XCTAssertNil(we[2].supersetUUID)
        // Fresh id, so the workout's grouping is independent of the routine.
        XCTAssertNotEqual(we[0].supersetUUID, routineGroup)
    }

    // MARK: workout -> routine

    func testUpdateRoutineFromWorkoutCarriesGrouping() {
        let (workout, e) = makeCurrentWorkout(exercises: 3)
        workout.makeSuperset(from: [e[0], e[1]])

        let routine = WorkoutRoutine.create(context: context)
        routine.update(fromWorkout: workout)
        let re = ordered(routine)
        XCTAssertEqual(re.count, 3)
        XCTAssertNotNil(re[0].supersetUUID)
        XCTAssertEqual(re[0].supersetUUID, re[1].supersetUUID)
        XCTAssertNil(re[2].supersetUUID)
    }

    // MARK: differs detects grouping change

    func testDiffersDetectsGroupingChange() {
        let (routine, e) = makeRoutine(exercises: 3)
        routine.makeSuperset(from: [e[0], e[1]])
        let workout = routine.createWorkout(context: context)

        // Same exercises, same sets, same grouping.
        XCTAssertFalse(routine.differs(fromWorkout: workout))

        // Break the grouping in the workout: now it differs.
        let we = ordered(workout)
        if let group = we[0].supersetUUID {
            workout.ungroupSuperset(id: group)
        }
        XCTAssertTrue(routine.differs(fromWorkout: workout))
    }

    // MARK: duplicate carries grouping

    func testDuplicateRoutineCarriesGrouping() {
        let (routine, e) = makeRoutine(exercises: 3)
        routine.makeSuperset(from: [e[0], e[1]])

        let copy = routine.duplicate(context: context)
        let ce = ordered(copy)
        XCTAssertEqual(ce.count, 3)
        XCTAssertNotNil(ce[0].supersetUUID)
        XCTAssertEqual(ce[0].supersetUUID, ce[1].supersetUUID)
        XCTAssertNil(ce[2].supersetUUID)
    }
}
