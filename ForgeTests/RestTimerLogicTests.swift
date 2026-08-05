//
//  RestTimerLogicTests.swift
//  ForgeTests
//

import XCTest
import Foundation
@testable import Forge

final class RestTimerLogicTests: XCTestCase {
    func testRunningTimerAdjustmentKeepsOriginalStart() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let start = now.addingTimeInterval(-30)

        let adjusted = RestTimerLogic.adjustedTimer(start: start, duration: 60, delta: 10, now: now)

        XCTAssertEqual(adjusted?.start, start)
        XCTAssertEqual(adjusted?.duration, 70)
    }

    func testExpiredTimerAdjustmentStartsFromNow() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let start = now.addingTimeInterval(-95)

        let adjusted = RestTimerLogic.adjustedTimer(start: start, duration: 60, delta: 10, now: now)

        XCTAssertEqual(adjusted?.start, now)
        XCTAssertEqual(adjusted?.duration, 10)
        XCTAssertEqual(adjusted.map { $0.start.addingTimeInterval($0.duration).timeIntervalSince(now) }, 10)
    }
}
