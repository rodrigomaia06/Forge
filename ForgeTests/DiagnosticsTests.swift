//
//  DiagnosticsTests.swift
//  ForgeTests
//

import XCTest
@testable import Forge

final class DiagnosticsTests: XCTestCase {
    func testPlainTextExportContainsReportSummaryAndPrivacyNotice() {
        let response = Date(timeIntervalSince1970: 1_000)
        let report = FreezeReport(
            date: Date(timeIntervalSince1970: 1_004),
            seconds: 4.5,
            lastResponse: response,
            breadcrumbs: [
                "00:16:40.000  value field focused",
                "00:16:41.000  keyboard did show",
            ]
        )

        let text = FreezeLogFormatter.text(for: [report])

        XCTAssertTrue(text.contains("Recorded freezes: 1"))
        XCTAssertTrue(text.contains("Privacy: fixed diagnostic event names and timings only"))
        XCTAssertTrue(text.contains("Unresponsive for 4.5 seconds"))
        XCTAssertTrue(text.contains("Recorded events: 2"))
        XCTAssertTrue(text.contains("value field focused"))
        XCTAssertTrue(text.contains("keyboard did show"))
    }

    func testExistingFreezeReportJSONStillDecodes() throws {
        let original = FreezeReport(
            date: Date(timeIntervalSince1970: 2_000),
            seconds: 3,
            lastResponse: Date(timeIntervalSince1970: 1_997),
            breadcrumbs: ["00:33:17.000  live workout rendered"]
        )

        let decoded = try JSONDecoder().decode(
            FreezeReport.self,
            from: JSONEncoder().encode(original)
        )

        XCTAssertEqual(decoded.date, original.date)
        XCTAssertEqual(decoded.seconds, original.seconds)
        XCTAssertEqual(decoded.lastResponse, original.lastResponse)
        XCTAssertEqual(decoded.breadcrumbs, original.breadcrumbs)
    }
}
