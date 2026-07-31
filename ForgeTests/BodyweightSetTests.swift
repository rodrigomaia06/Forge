//
//  BodyweightSetTests.swift
//  ForgeTests
//
//  A bodyweight set is a normal WorkoutSet with addedWeight set: the load is the added (+), pure (0), or
//  assisted (-) weight, and stats use that effective load. Normal sets (addedWeight nil) are unaffected.
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
        let normal = makeSet(weight: 80, added: nil, reps: 5)
        XCTAssertFalse(normal.isBodyweight)
        XCTAssertEqual(normal.effectiveWeightValue, 80)

        let pure = makeSet(weight: 0, added: 0, reps: 8)
        XCTAssertTrue(pure.isBodyweight)
        XCTAssertEqual(pure.effectiveWeightValue, 0)

        let weighted = makeSet(weight: 0, added: 20, reps: 5)
        XCTAssertTrue(weighted.isBodyweight)
        XCTAssertEqual(weighted.effectiveWeightValue, 20)

        let assisted = makeSet(weight: 0, added: -15, reps: 6)
        XCTAssertTrue(assisted.isBodyweight)
        XCTAssertEqual(assisted.effectiveWeightValue, -15)
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

    func testOneRepMaxUsesEffectiveWeight() {
        // Brzycki: 20 * 36 / (37 - 5) = 22.5
        let weighted = makeSet(weight: 0, added: 20, reps: 5)
        XCTAssertEqual(weighted.estimatedOneRepMax(maxReps: 10) ?? 0, 22.5, accuracy: 0.001)
        // A normal set is unchanged.
        let normal = makeSet(weight: 32, added: nil, reps: 5)
        XCTAssertEqual(normal.estimatedOneRepMax(maxReps: 10) ?? 0, 36, accuracy: 0.001)
    }
}
