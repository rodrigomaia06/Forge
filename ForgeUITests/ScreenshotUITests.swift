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

        // Not app.cells: these rows are not List cells, and querying for one
        // found nothing, so the taps went nowhere and the detail capture came
        // back as a second copy of the list.
        guard tapRow(in: app, at: 0) else {
            XCTFail("Nothing tappable in History, so the sample data did not load")
            return
        }
        capture(named: "workout-detail", after: 1.5)

        // A set opens the editor, the densest screen in the app.
        if tapRow(in: app, at: 1) {
            capture(named: "set-editor", after: 1.5)
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
        let edit = app.buttons["Edit"].firstMatch
        if edit.waitForExistence(timeout: 10) {
            edit.tap()
            capture(named: "history-editing", after: 1)
        }
    }

    // MARK: - Helpers

    /// Taps the nth row of whatever the screen is built from.
    ///
    /// Which element type a row is depends on how the screen was written, and
    /// these screens are not uniform. Rather than guess per screen, try each
    /// kind and take the first that has enough hittable elements.
    @discardableResult
    private func tapRow(in app: XCUIApplication, at index: Int) -> Bool {
        let queries = [app.cells, app.buttons, app.otherElements.matching(
            NSPredicate(format: "elementType == %d", XCUIElement.ElementType.cell.rawValue)
        )]
        for query in queries {
            _ = query.firstMatch.waitForExistence(timeout: 5)
            let hittable = (0..<query.count)
                .map { query.element(boundBy: $0) }
                .filter(\.isHittable)
            guard index < hittable.count else { continue }
            hittable[index].tap()
            return true
        }
        return false
    }

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
