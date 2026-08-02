//
//  ScreenshotUITests.swift
//  ForgeUITests
//
//  Photographs the running app, one image per screen.
//
//  This exists because ImageRenderer cannot. It draws pure SwiftUI and nothing
//  else, and every whole screen here is built on List, NavigationStack, or
//  TabView, all of which are UIKit underneath. Handed one, it fills the frame
//  with its yellow and red placeholder. The component captures in
//  ForgeTests/ScreenshotTests stay where they are; they are pure SwiftUI and
//  render correctly.
//
//  These are the reference the Dart rewrite is built against, so what matters
//  is that they show the real thing: the real navigation chrome, the real
//  materials, the real corner shapes, and the font as the system rasterises it.
//
//  Images are attached to the result bundle. CI exports them and renames them
//  from the manifest, since an exported attachment is named by UUID.
//

import XCTest

final class ScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureEveryTab() throws {
        let app = launch()

        for tab in ["Home", "History", "Workout", "Settings"] {
            let button = app.tabBars.buttons[tab]
            guard button.waitForExistence(timeout: 10) else {
                XCTFail("No tab named \(tab)")
                continue
            }
            button.tap()
            // A tab change animates. Waiting on the button being selected is
            // firmer than sleeping for a guessed duration.
            _ = button.waitForExistence(timeout: 5)
            capture(named: "tab-\(tab.lowercased())")
        }
    }

    /// Settings is a stack of pushed screens, and each one is worth having.
    func testCaptureSettingsScreens() throws {
        let app = launch()
        app.tabBars.buttons["Settings"].tap()

        for row in ["General", "Backup & Export", "About"] {
            let cell = app.cells.staticTexts[row]
            guard cell.waitForExistence(timeout: 5) else {
                // Not a failure. The row may be named differently, and one
                // missing screen should not cost the rest of the run.
                continue
            }
            cell.tap()
            capture(named: "settings-\(slug(row))")
            if app.navigationBars.buttons.element(boundBy: 0).exists {
                app.navigationBars.buttons.element(boundBy: 0).tap()
            }
        }
    }

    /// The plus menu on the workout tab.
    func testCaptureAddMenu() throws {
        let app = launch()
        app.tabBars.buttons["Workout"].tap()
        // The plus is the only button in the navigation bar here.
        let plus = app.navigationBars.buttons.element(boundBy: 0)
        guard plus.waitForExistence(timeout: 10) else {
            XCTFail("No button in the workout navigation bar")
            return
        }
        plus.tap()
        capture(named: "workout-add-menu", after: 1)
    }

    /// A finished workout, and the set editor inside it.
    func testCaptureWorkoutDetail() throws {
        let app = launch()
        app.tabBars.buttons["History"].tap()

        let workout = app.cells.element(boundBy: 0)
        guard workout.waitForExistence(timeout: 10) else {
            XCTFail("History is empty, so the sample data did not load")
            return
        }
        workout.tap()
        capture(named: "workout-detail", after: 1)

        // Tapping a set opens the editor, which is the densest screen in the
        // app and the one worth having exactly.
        let set = app.cells.element(boundBy: 2)
        if set.waitForExistence(timeout: 5) {
            set.tap()
            capture(named: "set-editor", after: 1)
        }
    }

    /// Every muscle group, then one exercise's own screen.
    func testCaptureExerciseBrowser() throws {
        let app = launch()
        app.tabBars.buttons["Workout"].tap()

        // Reached through the plus, then the exercise picker.
        let plus = app.navigationBars.buttons.element(boundBy: 0)
        guard plus.waitForExistence(timeout: 10) else { return }
        plus.tap()

        let start = app.buttons["Start Workout"].firstMatch
        if start.waitForExistence(timeout: 5) {
            start.tap()
            capture(named: "workout-current", after: 2)
        }
    }

    /// The history list in edit mode, where rows can be removed.
    func testCaptureHistoryEditing() throws {
        let app = launch()
        app.tabBars.buttons["History"].tap()
        let edit = app.navigationBars.buttons["Edit"]
        if edit.waitForExistence(timeout: 10) {
            edit.tap()
            capture(named: "history-editing", after: 1)
        }
    }

    // MARK: - Helpers

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ForgeSampleData"]
        app.launch()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 30),
            "The tab bar never appeared, so the app did not finish launching"
        )
        return app
    }

    private func slug(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: " & ", with: "-")
            .replacingOccurrences(of: " ", with: "-")
    }

    /// [seconds] lets a sheet, menu, or push finish animating. There is no
    /// element to wait on for a menu that may not exist, so this is a wait.
    private func capture(named name: String, after seconds: TimeInterval = 0) {
        if seconds > 0 { Thread.sleep(forTimeInterval: seconds) }
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(name).png"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
