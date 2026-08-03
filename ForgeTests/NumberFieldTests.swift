//
//  NumberFieldTests.swift
//  ForgeTests
//

import XCTest
@testable import Forge

final class NumberFieldTests: XCTestCase {
    func testMiddleInsertionIsAppendedAtRightEdge() {
        let result = RightAlignedNumberField.trailingReplacement(
            in: "1234",
            requestedRange: NSRange(location: 2, length: 0),
            replacement: "9"
        )

        XCTAssertEqual(result, "12349")
    }

    func testMiddleBackspaceDeletesFromRightEdge() {
        let result = RightAlignedNumberField.trailingReplacement(
            in: "1234",
            requestedRange: NSRange(location: 1, length: 1),
            replacement: ""
        )

        XCTAssertEqual(result, "123")
    }

    func testNativeTrailingInsertionAndDeletionNeedNoTranslation() {
        XCTAssertNil(
            RightAlignedNumberField.trailingReplacement(
                in: "1234",
                requestedRange: NSRange(location: 4, length: 0),
                replacement: "9"
            )
        )
        XCTAssertNil(
            RightAlignedNumberField.trailingReplacement(
                in: "1234",
                requestedRange: NSRange(location: 3, length: 1),
                replacement: ""
            )
        )
    }
}
