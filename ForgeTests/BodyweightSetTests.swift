//
//  BodyweightSetTests.swift
//  ForgeTests
//
//  A bodyweight set is a WorkoutSet with addedWeight set (zero for a pure bodyweight rep). Its effective
//  load is the user's bodyweight plus the added (+) or assisted (-) weight; stats use that load. Normal
//  sets (addedWeight nil) ignore bodyweight and use their absolute weight.
//

import XCTest
import CoreData
import WorkoutDataKit
@testable import Forge

final class BodyweightSetTests: XCTestCase {
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

    private func makeSet(weight: Double, added: Double?, reps: Int16) -> WorkoutSet {
        let set = WorkoutSet.create(context: context)
        set.weightValue = weight
        set.addedWeightValue = added
        set.repetitionsValue = reps
        return set
    }

    func testIsBodyweightAndEffectiveWeight() {
        let bw = 75.0

        let normal = makeSet(weight: 80, added: nil, reps: 5)
        XCTAssertFalse(normal.isBodyweight)
        XCTAssertEqual(normal.effectiveWeight(fallbackBodyweight: bw), 80) // bodyweight is ignored for normal sets

        let pure = makeSet(weight: 0, added: 0, reps: 8)
        XCTAssertTrue(pure.isBodyweight)
        XCTAssertEqual(pure.effectiveWeight(fallbackBodyweight: bw), 75) // just the bodyweight

        let weighted = makeSet(weight: 0, added: 20, reps: 5)
        XCTAssertTrue(weighted.isBodyweight)
        XCTAssertEqual(weighted.effectiveWeight(fallbackBodyweight: bw), 95) // bodyweight + added

        let assisted = makeSet(weight: 0, added: -15, reps: 6)
        XCTAssertTrue(assisted.isBodyweight)
        XCTAssertEqual(assisted.effectiveWeight(fallbackBodyweight: bw), 60) // bodyweight - assist

        // With bodyweight unset (0), only the added weight counts.
        XCTAssertEqual(weighted.effectiveWeight(fallbackBodyweight: 0), 20)
    }

    func testFrozenWorkoutBodyweightWinsOverFallback() {
        // A set on a finished workout uses that workout's frozen bodyweight, not the current setting.
        let workout = Workout.create(context: context)
        let exercise = WorkoutExercise.create(context: context)
        exercise.workout = workout
        let set = makeSet(weight: 0, added: 20, reps: 5)
        set.workoutExercise = exercise

        workout.bodyweightValue = 70
        XCTAssertEqual(set.effectiveWeight(fallbackBodyweight: 999), 90) // 70 (frozen) + 20, fallback ignored

        // Without a frozen value (workout still in progress), the fallback is used.
        workout.bodyweightValue = nil
        XCTAssertEqual(set.effectiveWeight(fallbackBodyweight: 80), 100) // 80 (fallback) + 20
    }

    func testDisplayTitle() {
        XCTAssertEqual(makeSet(weight: 0, added: 0, reps: 8).displayTitle(weightUnit: .metric), "BW × 8")

        let weighted = makeSet(weight: 0, added: 20, reps: 5).displayTitle(weightUnit: .metric)
        XCTAssertTrue(weighted.hasPrefix("BW + "), weighted)
        XCTAssertTrue(weighted.hasSuffix("× 5"), weighted)

        let assisted = makeSet(weight: 0, added: -15, reps: 6).displayTitle(weightUnit: .metric)
        XCTAssertTrue(assisted.hasPrefix("BW - "), assisted)

        let normal = makeSet(weight: 80, added: nil, reps: 5).displayTitle(weightUnit: .metric)
        XCTAssertFalse(normal.hasPrefix("BW"), normal)
    }

    func testOneRepMaxFactorsBodyweight() {
        // Brzycki on the effective load: (75 + 20) * 36 / (37 - 5) = 106.875
        let weighted = makeSet(weight: 0, added: 20, reps: 5)
        XCTAssertEqual(weighted.estimatedOneRepMax(maxReps: 10, fallbackBodyweight: 75) ?? 0, 106.875, accuracy: 0.001)
        // A normal set ignores bodyweight: 32 * 36 / (37 - 5) = 36
        let normal = makeSet(weight: 32, added: nil, reps: 5)
        XCTAssertEqual(normal.estimatedOneRepMax(maxReps: 10, fallbackBodyweight: 75) ?? 0, 36, accuracy: 0.001)
    }
}
