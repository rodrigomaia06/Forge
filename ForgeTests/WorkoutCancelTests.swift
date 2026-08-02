//
//  WorkoutCancelTests.swift
//  ForgeTests
//
//  Discarding a workout must actually delete it. A capture run photographed the app showing
//  "Couldn't discard workout — Something went wrong, so your workout was kept.", which is the error
//  path in Workout.cancelOrCrash, so the save inside cancel() threw. These pin down which shape of
//  workout does it.
//
//  The shapes matter because cancel() deletes the workout and saves in one step, and the model
//  validates on save: WorkoutSet rejects an uncompleted set whose workout is not the current one, and
//  Workout rejects a finished workout with no start or end. A cascade delete has to get past both.
//

import XCTest
import CoreData
import WorkoutDataKit

final class WorkoutCancelTests: XCTestCase {
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

    /// A current workout with `exerciseCount` exercises of `setsPerExercise` sets each. `completed`
    /// decides whether those sets are logged or still blank, which is what the set validator keys on.
    @discardableResult
    private func makeCurrentWorkout(exerciseCount: Int, setsPerExercise: Int, completed: Bool) -> Workout {
        let workout = Workout.create(context: context)
        workout.isCurrentWorkout = true
        workout.start = Date(timeIntervalSince1970: 1_000)
        for _ in 0..<exerciseCount {
            let workoutExercise = WorkoutExercise.create(context: context)
            workout.addToWorkoutExercises(workoutExercise)
            workoutExercise.exerciseUuid = UUID()
            for _ in 0..<setsPerExercise {
                let set = WorkoutSet.create(context: context)
                set.workoutExercise = workoutExercise
                if completed {
                    set.weightValue = 60
                    set.repetitionsValue = 5
                    set.isCompleted = true
                }
            }
        }
        try! context.save()
        return workout
    }

    private func assertDiscards(_ workout: Workout, _ message: String) {
        let objectID = workout.objectID
        XCTAssertNoThrow(try workout.cancel(), message)
        XCTAssertNil(try? context.existingObject(with: objectID), "\(message): the workout survived the discard")
        XCTAssertEqual(try context.count(for: Workout.currentWorkoutFetchRequest), 0, "\(message): a current workout is still on file")
    }

    /// The shape the app is actually in mid-session: sets added but not yet logged.
    func testDiscardsWorkoutWithUncompletedSets() {
        let workout = makeCurrentWorkout(exerciseCount: 2, setsPerExercise: 3, completed: false)
        assertDiscards(workout, "A workout with uncompleted sets")
    }

    func testDiscardsWorkoutWithCompletedSets() {
        let workout = makeCurrentWorkout(exerciseCount: 2, setsPerExercise: 3, completed: true)
        assertDiscards(workout, "A workout with completed sets")
    }

    /// Some logged, some not, which is the state a workout is in partway through.
    func testDiscardsPartiallyCompletedWorkout() {
        let workout = makeCurrentWorkout(exerciseCount: 1, setsPerExercise: 0, completed: false)
        let workoutExercise = WorkoutExercise.create(context: context)
        workout.addToWorkoutExercises(workoutExercise)
        workoutExercise.exerciseUuid = UUID()
        for index in 0..<4 {
            let set = WorkoutSet.create(context: context)
            set.workoutExercise = workoutExercise
            if index < 2 {
                set.weightValue = 80
                set.repetitionsValue = 5
                set.isCompleted = true
            }
        }
        try! context.save()
        assertDiscards(workout, "A part-logged workout")
    }

    func testDiscardsEmptyWorkout() {
        let workout = makeCurrentWorkout(exerciseCount: 0, setsPerExercise: 0, completed: false)
        assertDiscards(workout, "An empty workout")
    }

    /// The sample data's shape: a workout linked to the routine it came from. The routine must outlive
    /// the discard, since discarding a session is not deleting the plan it was based on.
    func testDiscardingWorkoutFromRoutineKeepsTheRoutine() {
        let plan = WorkoutPlan.create(context: context)
        plan.title = "StrongLifts 5x5"
        let routine = WorkoutRoutine.create(context: context)
        routine.title = "Workout A"
        routine.workoutPlan = plan
        let workout = routine.createWorkout(context: context)
        workout.isCurrentWorkout = true
        workout.start = Date(timeIntervalSince1970: 1_000)
        try! context.save()

        let routineID = routine.objectID
        assertDiscards(workout, "A workout started from a routine")
        XCTAssertNotNil(try? context.existingObject(with: routineID), "The routine was deleted along with the workout")
    }

    /// A workout that has been through supersetting, since grouping writes a shared id onto each member
    /// and the discard has to take the whole group with it.
    func testDiscardsWorkoutWithSuperset() {
        let workout = makeCurrentWorkout(exerciseCount: 3, setsPerExercise: 2, completed: false)
        let exercises = workout.workoutExercises?.array as? [WorkoutExercise] ?? []
        XCTAssertEqual(exercises.count, 3)
        workout.makeSuperset(from: Array(exercises.prefix(2)))
        try! context.save()
        assertDiscards(workout, "A workout containing a superset")
    }
}
