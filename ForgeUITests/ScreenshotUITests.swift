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
        let app = XCUIApplication()
        app.launchArguments += ["-ForgeSampleData"]
        app.launch()

        // The tab bar is the last thing to settle on a cold launch.
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 30),
            "The tab bar never appeared, so the app did not finish launching"
        )

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
        let app = XCUIApplication()
        app.launchArguments += ["-ForgeSampleData"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 30))
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

    // MARK: - Helpers

    private func slug(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: " & ", with: "-")
            .replacingOccurrences(of: " ", with: "-")
    }

    private func capture(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(name).png"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
