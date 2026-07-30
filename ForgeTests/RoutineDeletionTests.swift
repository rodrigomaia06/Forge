//
//  RoutineDeletionTests.swift
//  ForgeTests
//
//  Deleting a routine (or its plan) must not delete the finished workouts that came from it, and a
//  workout that borrowed its name from the routine keeps that name instead of falling back to a
//  generated one.
//

import XCTest
import CoreData
import WorkoutDataKit

final class RoutineDeletionTests: XCTestCase {
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

    /// Builds a plan and routine with the given titles and a workout created from the routine.
    private func makePlanRoutineWorkout(planTitle: String?, routineTitle: String?) -> (WorkoutPlan, WorkoutRoutine, Workout) {
        let plan = WorkoutPlan.create(context: context)
        plan.title = planTitle
        let routine = WorkoutRoutine.create(context: context)
        routine.title = routineTitle
        routine.workoutPlan = plan
        let workout = routine.createWorkout(context: context)
        // A finished (non-current) workout must have a start and end to pass validation on save.
        workout.start = Date(timeIntervalSince1970: 1_000)
        workout.end = Date(timeIntervalSince1970: 2_000)
        try! context.save()
        return (plan, routine, workout)
    }

    func testBorrowedTitleIsSnapshotWhenRoutineDeleted() {
        let (_, routine, workout) = makePlanRoutineWorkout(planTitle: "Push pull legs", routineTitle: "Push day")
        // The workout has no name of its own, so it shows the plan and routine name.
        XCTAssertNil(workout.title)
        XCTAssertEqual(workout.optionalDisplayTitle(in: []), "Push pull legs - Push day")

        context.delete(routine)
        try! context.save()

        // The workout survives, detached from the routine, and keeps the name it was showing.
        XCTAssertFalse(workout.isDeleted)
        XCTAssertNil(workout.workoutRoutine)
        XCTAssertEqual(workout.title, "Push pull legs - Push day")
        XCTAssertEqual(workout.optionalDisplayTitle(in: []), "Push pull legs - Push day")
    }

    func testCustomTitleIsNotOverwrittenWhenRoutineDeleted() {
        let (_, routine, workout) = makePlanRoutineWorkout(planTitle: "Push pull legs", routineTitle: "Push day")
        workout.title = "Morning session"
        try! context.save()

        context.delete(routine)
        try! context.save()

        XCTAssertFalse(workout.isDeleted)
        XCTAssertEqual(workout.title, "Morning session")
    }

    func testBorrowedTitleIsSnapshotWhenPlanDeleted() {
        let (plan, _, workout) = makePlanRoutineWorkout(planTitle: "Push pull legs", routineTitle: "Push day")

        // Deleting the plan cascades to the routine; the workout should survive with the full name.
        context.delete(plan)
        try! context.save()

        XCTAssertFalse(workout.isDeleted)
        XCTAssertNil(workout.workoutRoutine)
        XCTAssertEqual(workout.title, "Push pull legs - Push day")
    }
}
