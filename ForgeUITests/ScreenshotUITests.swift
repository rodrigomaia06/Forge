//
//  ScreenshotUITests.swift
//  ForgeUITests
//
//  Drives the running app through every screen it has and photographs each step, including the
//  states that only exist mid-interaction: an open menu, a half-filled field, an alert, a sheet at
//  its detent, a list in edit mode. Animations are the one thing these cannot show.
//
//  This exists because ImageRenderer cannot photograph a whole screen. It draws pure SwiftUI and
//  nothing else, and every screen here is built on List, NavigationStack, or TabView, all of which
//  are UIKit underneath. Handed one, it fills the frame with its yellow and red placeholder. The
//  component captures in ForgeTests/ScreenshotTests stay where they are; they are pure SwiftUI and
//  render correctly.
//
//  Each test is one journey with its own launch, so a path that breaks costs only its own images.
//  Within a journey a step that cannot be reached records a note and a hierarchy dump next to the
//  images instead of failing, because a capture run is worth more for the screens it did reach than
//  for the one it did not. Only a failed launch fails the run.
//
//  Images are named "<journey>-<step>-<screen>.png" so they sort in the order the app was driven.
//  No underscores: an exported attachment is renamed from the manifest by the part of its name
//  before the first underscore.
//

import XCTest

final class ScreenshotUITests: XCTestCase {

    private var app: XCUIApplication!
    private var journey = ""
    private var step = 0

    override func setUpWithError() throws {
        // One unreachable step should not end the journey; the helpers below record and move on.
        continueAfterFailure = true
    }

    // MARK: - Journeys

    /// The four tabs, top and bottom, which is the frame of reference for everything else.
    func testTabs() throws {
        launch("tabs")

        for tab in ["Home", "History", "Workout", "Settings"] {
            guard let button = tabButton(tab) else {
                skipped("the \(tab) tab")
                continue
            }
            button.tap()
            shot(slug(tab))
            app.swipeUp(velocity: .slow)
            shot("\(slug(tab))-scrolled")
            app.swipeDown(velocity: .slow)
        }
    }

    /// The dashboard: quick stats, the month grid, the year grid, a zoomed month, and the day and
    /// month filters that drive the list underneath.
    func testHome() throws {
        launch("home")
        selectTab("Home")
        shot("dashboard")

        // The activity header toggles the month grid into a year of month grids.
        if tapFirst(in: [app.buttons], labelled: "activity") || tapMonthHeader() {
            shot("year-calendar")
            // A month in the year grid zooms into its own grid and filters the list to that month.
            if let month = app.buttons.allElementsBoundByIndex.first(where: {
                $0.isHittable && $0.label.localizedCaseInsensitiveContains("workout") && $0.label.count < 40
            }) {
                month.tap()
                shot("month-zoomed")
                app.swipeUp(velocity: .slow)
                shot("month-filtered-list")
                app.swipeDown(velocity: .slow)
                // The header is a back affordance while zoomed.
                _ = tapFirst(in: [app.buttons], labelled: "Back to year")
                shot("year-calendar-after-back")
            }
        } else {
            skipped("the activity calendar header")
        }

        // A day in the month grid filters the list to that day.
        if let day = app.buttons.allElementsBoundByIndex.first(where: {
            $0.isHittable && $0.label.localizedCaseInsensitiveContains("workout logged")
        }) {
            day.tap()
            shot("day-filtered")
            _ = tapFirst(in: [app.buttons], labelled: "Clear filter")
            shot("filter-cleared")
        } else {
            skipped("a day with a workout on it")
        }

        // A recent card opens that workout in History.
        app.swipeUp(velocity: .slow)
        shot("recent-workouts")
        if tapRow(at: 0, preferring: [app.buttons]) {
            shot("card-opened-in-history", settle: 1.5)
        }
    }

    /// History: the list, its date filter, the row context menu, edit mode, a workout, an exercise
    /// inside it, and the sheets that hang off the exercise.
    func testHistory() throws {
        launch("history")
        selectTab("History")
        shot("list")

        if tapFirst(in: [app.buttons], labelled: "Filter by date") {
            shot("date-filter")
            _ = tapFirst(in: [app.buttons], labelled: "Hide date filter")
        } else {
            skipped("the date filter button")
        }

        // Long-pressing a row is how Share, Repeat and Delete are reached.
        if let row = firstHittable(in: [app.cells, app.buttons]) {
            row.press(forDuration: 1.2)
            shot("row-context-menu", settle: 1.5)
            dismissOverlay()
        } else {
            skipped("a history row to long-press")
        }

        if tapFirst(in: [app.buttons], labelled: "Edit") {
            shot("edit-mode")
            // A row in edit mode offers the delete control.
            if let row = firstHittable(in: [app.cells, app.buttons]) {
                row.swipeLeft()
                shot("swipe-to-delete")
                row.swipeRight()
            }
            _ = tapFirst(in: [app.buttons], labelled: "Done")
        } else {
            skipped("the Edit button on History")
        }

        guard tapRow(at: 0, preferring: [app.cells, app.buttons]) else {
            skipped("a workout row to open")
            return
        }
        shot("workout-detail", settle: 1.5)
        app.swipeUp(velocity: .slow)
        shot("workout-detail-scrolled")
        app.swipeDown(velocity: .slow)

        // An exercise inside the workout pushes its own read-only screen.
        if tapRow(at: 1, preferring: [app.cells, app.buttons]) {
            shot("exercise-detail", settle: 1.5)
            captureExerciseOptionsMenu(prefix: "history")
            if tapFirst(in: [app.buttons], labelled: "Edit") {
                shot("exercise-editable")
                _ = tapFirst(in: [app.buttons], labelled: "Done")
            }
            back()
        } else {
            skipped("an exercise row inside the workout")
        }
    }

    /// The live workout, which is where the app is actually used: the set table, the value fields
    /// and their keyboards, completing a set, the rest timer, the exercise menu and its sheets, the
    /// superset card, adding an exercise, reordering, and the finish and discard alerts.
    func testRunningWorkout() throws {
        launch("workout")
        selectTab("Workout")

        guard app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 10) else {
            skipped("the running workout (the sample data changed shape)")
            return
        }
        shot("running", settle: 1.5)
        app.swipeUp(velocity: .slow)
        shot("running-scrolled")
        app.swipeDown(velocity: .slow)

        // The set number chip opens that set's options: tag, note, next-time target, RPE.
        if tapFirst(in: [app.buttons], labelled: "Details") {
            shot("set-options-sheet", settle: 1.5)
            app.swipeUp(velocity: .slow)
            shot("set-options-scrolled")
            dismissSheet()
        } else {
            skipped("a set's details chip")
        }

        // The weight and reps boxes, and the number pad they raise.
        captureValueEntry()

        // Completing a set starts the rest timer, so this has to come before the timer captures.
        if tapFirst(in: [app.buttons], labelled: "Complete set") {
            shot("set-completed", settle: 1.5)
        } else {
            skipped("a set's complete button")
        }

        captureTimers()
        captureExerciseOptionsMenu(prefix: "workout")
        captureSupersetMenu()

        // Adding an exercise: the picker, its filters, and a multi-selection.
        if tapFirst(in: [app.buttons, app.cells, app.staticTexts], labelled: "Add exercise") {
            shot("add-exercise-sheet", settle: 1.5)
            if tapFirst(in: [app.buttons], labelled: "Filter exercises") {
                shot("add-exercise-filters", settle: 1.2)
                dismissOverlay()
            }
            if tapRow(at: 1, preferring: [app.cells, app.buttons]) {
                shot("add-exercise-selected", settle: 1)
            }
            if !tapFirst(in: [app.buttons], labelled: "Cancel") { dismissSheet() }
        } else {
            skipped("the Add exercise row")
        }

        // Edit mode collapses the exercises into a reorderable list.
        if tapFirst(in: [app.buttons], labelled: "Edit") {
            shot("edit-mode", settle: 1.2)
            // The stopwatch is only editable here, so this is the one place the time editor opens.
            if tapFirst(in: [app.buttons], labelled: "clock") || tapStopwatch() {
                shot("edit-workout-time", settle: 1.2)
                if !tapFirst(in: [app.buttons], labelled: "Close") { dismissSheet() }
            }
            _ = tapFirst(in: [app.buttons], labelled: "Done")
            shot("edit-mode-done", settle: 1)
        } else {
            skipped("the Edit button on the running workout")
        }

        // Finish, then step back out of the confirmation without finishing.
        if tapFirst(in: [app.buttons], labelled: "Finish") {
            shot("finish-confirmation", settle: 1.2)
            pressAlertButton("Cancel", fallbackOffset: CGVector(dx: 0.332, dy: 0.552))
        } else {
            skipped("the Finish button")
        }

        // Discard, which is the way back to the plans list.
        if tapFirst(in: [app.buttons], labelled: "Cancel") {
            shot("discard-alert", settle: 1.2)
            pressAlertButton("Discard", fallbackOffset: CGVector(dx: 0.668, dy: 0.552))
            shot("after-discard", settle: 2.5)
        } else {
            skipped("the Cancel button on the running workout")
        }
    }

    /// Reproduces the freeze ordering: a focused value field commits as the set-options sheet opens.
    /// The sheet must finish presenting, dismiss, and return touch input to the live workout.
    func testSetOptionsSurvivesUnderlyingValueCommit() throws {
        continueAfterFailure = false
        launch("set-options-commit")
        selectTab("Workout")

        XCTAssertTrue(app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 10))
        let weight = app.textFields.firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap()
        guard app.keyboards.firstMatch.waitForExistence(timeout: 3) else {
            throw XCTSkip("The simulator did not show a software keyboard.")
        }

        let details = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Details")).firstMatch
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        XCTAssertTrue(details.isHittable)
        details.tap()

        XCTAssertTrue(app.buttons["Delete set"].firstMatch.waitForExistence(timeout: 5))
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()

        let returnedWeight = app.textFields.firstMatch
        XCTAssertTrue(returnedWeight.waitForExistence(timeout: 5))
        returnedWeight.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
    }

    /// Reproduces the current-device trace: complete a set while a value field owns the keyboard, then
    /// scroll. Scrolling must leave focus alone; after an explicit Done, wait beyond the in-app monitor's
    /// three-second threshold before proving that another field can still take focus.
    func testValueFieldTeardownSurvivesSetCompletion() throws {
        continueAfterFailure = false
        launch("value-field-teardown")
        selectTab("Workout")

        XCTAssertTrue(app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 10))
        let firstField = app.textFields.firstMatch
        XCTAssertTrue(firstField.waitForExistence(timeout: 5))
        firstField.tap()
        guard app.keyboards.firstMatch.waitForExistence(timeout: 3) else {
            throw XCTSkip("The simulator did not show a software keyboard.")
        }

        let complete = app.buttons["Complete set"].firstMatch
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        XCTAssertTrue(complete.isHittable)
        complete.tap()

        app.swipeUp(velocity: .slow)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))

        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        done.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))

        let stayedResponsive = expectation(description: "Main thread stays responsive past hang threshold")
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { stayedResponsive.fulfill() }
        wait(for: [stayedResponsive], timeout: 5)

        let fields = app.textFields
        XCTAssertGreaterThan(fields.count, 1)
        let secondField = fields.element(boundBy: 1)
        XCTAssertTrue(secondField.waitForExistence(timeout: 3))
        secondField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
    }

    /// The Workout tab with nothing running: the plans list, the add menu, and the routine and plan
    /// editors reached from it.
    func testWorkoutPlans() throws {
        launch("plans")
        selectTab("Workout")
        discardRunningWorkout()
        shot("plans-list", settle: 2)

        guard tapFirst(in: [app.buttons], labelled: "Add") || tapNavigationBarFirstButton() else {
            skipped("the add menu")
            return
        }
        shot("add-menu", settle: 1.5)

        // A new routine opens its editor straight away.
        if tapFirst(in: [app.buttons, app.cells, app.staticTexts], labelled: "New routine") {
            shot("new-routine", settle: 2)
            captureRoutineEditor()
            back()
        } else {
            skipped("the New routine menu item")
            dismissOverlay()
        }

        // A plan is created in place, then opened from the list.
        if tapFirst(in: [app.buttons], labelled: "Add") || tapNavigationBarFirstButton() {
            if tapFirst(in: [app.buttons, app.cells, app.staticTexts], labelled: "New workout plan") {
                shot("new-plan-created", settle: 2)
            } else {
                dismissOverlay()
            }
        }

        // An existing plan from the sample data, and a routine inside it.
        if tapFirst(in: [app.cells, app.buttons, app.staticTexts], labelled: "StrongLifts") {
            shot("plan-detail", settle: 1.5)
            if tapRow(at: 1, preferring: [app.cells, app.buttons]) {
                shot("plan-routine", settle: 1.5)
                captureRoutineEditor()
                back()
            }
            back()
        } else {
            skipped("the sample workout plan")
        }
    }

    /// The exercise browser, reached through Settings: muscle groups, one group's list, one
    /// exercise, and that exercise's history and statistics.
    func testExercises() throws {
        launch("exercises")
        selectTab("Settings")

        guard tapFirst(in: [app.cells, app.buttons, app.staticTexts], labelled: "Exercises") else {
            skipped("the Exercises row in Settings")
            return
        }
        shot("muscle-groups", settle: 1.2)
        app.swipeUp(velocity: .slow)
        shot("muscle-groups-scrolled")
        app.swipeDown(velocity: .slow)

        // "All" is a group like any other and is always present.
        guard tapFirst(in: [app.cells, app.buttons, app.staticTexts], labelled: "All") else {
            skipped("a muscle group to open")
            return
        }
        shot("exercise-list", settle: 1.2)

        // The search field is the main way into a long list.
        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 3) {
            search.tap()
            typeIfPossible(into: search, "squat")
            shot("exercise-search", settle: 1.2)
            _ = tapFirst(in: [app.buttons], labelled: "Cancel")
        } else {
            skipped("the exercise search field")
        }

        guard tapRow(at: 0, preferring: [app.cells, app.buttons]) else {
            skipped("an exercise to open")
            return
        }
        shot("exercise-info", settle: 1.5)
        app.swipeUp(velocity: .slow)
        shot("exercise-info-scrolled")
        app.swipeDown(velocity: .slow)

        for item in ["History", "Statistics"] {
            guard tapFirst(in: [app.buttons], labelled: item) else {
                skipped("the \(item) button on the exercise")
                continue
            }
            shot("exercise-\(slug(item))", settle: 2)
            if !tapFirst(in: [app.buttons], labelled: "Close") { back() }
        }
    }

    /// Every Settings screen, and the controls on them that open something of their own.
    func testSettings() throws {
        launch("settings")
        selectTab("Settings")
        shot("root")

        for row in ["General", "Backup & Export", "About"] {
            guard tapFirst(in: [app.cells, app.buttons, app.staticTexts], labelled: row) else {
                skipped("the \(row) row")
                continue
            }
            shot(slug(row), settle: 1.2)
            app.swipeUp(velocity: .slow)
            shot("\(slug(row))-scrolled")
            app.swipeDown(velocity: .slow)

            if row == "General" {
                // A picker row pushes its own options screen.
                if tapFirst(in: [app.cells, app.buttons, app.staticTexts], labelled: "Theme") {
                    shot("general-theme-options", settle: 1.2)
                    back()
                }
                if tapFirst(in: [app.cells, app.buttons, app.staticTexts], labelled: "Default rest time") {
                    shot("general-rest-time-options", settle: 1.2)
                    back()
                }
            }
            if row == "Backup & Export" {
                // The destructive path, up to its confirmation, which is then declined.
                if tapFirst(in: [app.buttons, app.staticTexts], labelled: "Reset all data") {
                    shot("reset-confirmation", settle: 1.2)
                    pressAlertButton("Cancel", fallbackOffset: CGVector(dx: 0.332, dy: 0.552))
                }
            }
            back()
        }
    }

    /// The app in light mode. Forge is dark-first, so this is the appearance the reference images
    /// would otherwise never show. Changed through Settings, the way a user would.
    func testLightAppearance() throws {
        launch("light")
        selectTab("Settings")

        guard tapFirst(in: [app.cells, app.buttons, app.staticTexts], labelled: "General"),
              tapFirst(in: [app.cells, app.buttons, app.staticTexts], labelled: "Theme"),
              tapFirst(in: [app.cells, app.buttons, app.staticTexts], labelled: "Light")
        else {
            skipped("the appearance picker")
            return
        }
        shot("theme-picked", settle: 1.5)
        back()
        shot("settings-light", settle: 1.2)

        for tab in ["Home", "History", "Workout"] {
            guard let button = tabButton(tab) else { continue }
            button.tap()
            shot("\(slug(tab))-light", settle: 1.5)
        }
    }

    // MARK: - Composite captures

    /// The value boxes and the number pad. Typing needs the software keyboard, which is not up on
    /// every runner, so the entry itself is optional while the raised-keyboard shot is not.
    private func captureValueEntry() {
        // Queried fresh at each use, never held across a tap. A bound element captured before the tap
        // stops resolving once the keyboard changes the hierarchy, and touching a stale one raises
        // "Failed to get matching snapshot", which ends the test method the same way a failed type does.
        guard app.textFields.firstMatch.waitForExistence(timeout: 4) else {
            skipped("the set's value fields")
            return
        }
        let weight = app.textFields.element(boundBy: 0)
        guard weight.exists, weight.isHittable else {
            skipped("a hittable weight field")
            return
        }
        weight.tap()
        shot("value-field-focused", settle: 1.2)
        typeIfPossible(into: app.textFields.element(boundBy: 0), "60")
        shot("value-typed", settle: 0.8)

        let reps = app.textFields.element(boundBy: 1)
        if reps.exists, reps.isHittable {
            reps.tap()
            typeIfPossible(into: app.textFields.element(boundBy: 1), "8")
            shot("reps-typed", settle: 0.8)
        }
        // Scrolling a focused List used to start a second responder transition and permanently block the
        // main thread on device. It now only scrolls; Done is the one explicit dismissal in this path.
        app.swipeUp(velocity: .slow)
        shot("value-field-scrolled", settle: 0.8)
        _ = tapFirst(in: [app.buttons], labelled: "Done")
        shot("keyboard-dismissed", settle: 0.8)
        app.swipeDown(velocity: .slow)
    }

    /// The two timers in the workout header: the elapsed stopwatch and the rest timer sheet, in
    /// both of its states.
    private func captureTimers() {
        guard tapFirst(in: [app.buttons], labelled: "timer") || tapRestTimer() else {
            skipped("the rest timer button")
            return
        }
        shot("rest-timer", settle: 1.5)
        for adjust in ["+10s", "\u{2212}10s"] {
            if tapFirst(in: [app.buttons, app.staticTexts], labelled: adjust) {
                shot("rest-timer-\(adjust == "+10s" ? "plus" : "minus")", settle: 0.8)
            }
        }
        if tapFirst(in: [app.buttons], labelled: "Skip rest") {
            shot("rest-timer-stopped", settle: 1.2)
        }
        if !tapFirst(in: [app.buttons], labelled: "Close") { dismissSheet() }

        // Outside edit mode the stopwatch only explains that it is editable in Edit.
        if tapStopwatch() {
            shot("stopwatch-hint", settle: 0.8)
        }
    }

    /// An exercise's "..." menu and every screen behind it.
    private func captureExerciseOptionsMenu(prefix: String) {
        guard tapEllipsis() else {
            skipped("\(prefix): an exercise's options menu")
            return
        }
        shot("\(prefix)-exercise-menu", settle: 1.5)

        let items = ["Add note", "Change note", "Previous sessions", "Warm-up sets", "Exercise info"]
        var opened: String?
        for item in items {
            if tapFirst(in: [app.buttons, app.staticTexts], labelled: item) {
                opened = item
                break
            }
        }
        guard let opened else {
            dismissOverlay()
            return
        }
        shot("\(prefix)-\(slug(opened))", settle: 1.5)
        if !tapFirst(in: [app.buttons], labelled: "Done") { dismissSheet() }

        // The remaining items, one reopening of the menu each.
        for item in items where item != opened {
            guard tapEllipsis() else { break }
            guard tapFirst(in: [app.buttons, app.staticTexts], labelled: item) else {
                dismissOverlay()
                continue
            }
            shot("\(prefix)-\(slug(item))", settle: 1.5)
            if !tapFirst(in: [app.buttons], labelled: "Done") { dismissSheet() }
        }
    }

    /// The superset card's own menu, which owns the shared note and ungrouping.
    private func captureSupersetMenu() {
        guard let group = app.buttons.allElementsBoundByIndex.first(where: {
            $0.isHittable && $0.label.localizedCaseInsensitiveContains("superset")
        }) else {
            skipped("a superset card")
            return
        }
        group.tap()
        shot("superset-menu", settle: 1.5)
        if tapFirst(in: [app.buttons, app.staticTexts], labelled: "note") {
            shot("superset-note", settle: 1.5)
            if !tapFirst(in: [app.buttons], labelled: "Done") { dismissSheet() }
        } else {
            dismissOverlay()
        }
    }

    /// A routine editor: its characteristics, its set rows, the per-set editor, and the exercise
    /// menu with its nested pickers.
    private func captureRoutineEditor() {
        shot("routine-editor", settle: 1.5)
        app.swipeUp(velocity: .slow)
        shot("routine-editor-scrolled")
        app.swipeDown(velocity: .slow)

        if tapFirst(in: [app.buttons, app.staticTexts], labelled: "Add exercises") {
            shot("routine-add-exercises", settle: 1.5)
            if !tapFirst(in: [app.buttons], labelled: "Cancel") { dismissSheet() }
        } else {
            skipped("the Add exercises button in the routine editor")
        }

        if tapFirst(in: [app.buttons], labelled: "Exercise options") || tapEllipsis() {
            shot("routine-exercise-menu", settle: 1.5)
            // Rep target and Weight are submenus, so opening one shows the nested level.
            if tapFirst(in: [app.buttons, app.staticTexts], labelled: "Rep target") {
                shot("routine-rep-target-submenu", settle: 1.2)
            }
            dismissOverlay()
        } else {
            skipped("the routine exercise menu")
        }

        if tapFirst(in: [app.buttons, app.staticTexts], labelled: "Add set") {
            shot("routine-set-added", settle: 1.2)
        }
    }

    // MARK: - Navigation helpers

    private func discardRunningWorkout() {
        let cancel = app.buttons["Cancel"].firstMatch
        guard cancel.waitForExistence(timeout: 8) else { return }
        cancel.tap()
        // The alert is photographed happily, so it is on screen, but on iOS 26 the accessibility
        // hierarchy rooted at the app has contained no alert and no Discard: it is presented in a
        // window these queries do not reach. Position is the surer handle than text here; the offset
        // comes off a capture, where the Discard pill centres at (0.668, 0.552) of the screen.
        pressAlertButton("Discard", fallbackOffset: CGVector(dx: 0.668, dy: 0.552))
        _ = app.buttons["Add"].firstMatch.waitForExistence(timeout: 8)
    }

    private func tabButton(_ name: String) -> XCUIElement? {
        let button = app.tabBars.buttons[name]
        return button.waitForExistence(timeout: 10) ? button : nil
    }

    private func selectTab(_ name: String) {
        guard let button = tabButton(name) else {
            skipped("the \(name) tab")
            return
        }
        button.tap()
        // A tab change animates. Waiting on the button being selected is firmer than a guessed sleep.
        _ = button.waitForExistence(timeout: 5)
    }

    private func back() {
        let button = app.navigationBars.buttons.element(boundBy: 0)
        if button.exists && button.isHittable {
            button.tap()
        } else {
            // A pushed screen with a hidden bar still pops on the edge swipe.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
                .press(forDuration: 0.05,
                       thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        }
        _ = app.wait(for: .runningForeground, timeout: 2)
    }

    private func tapNavigationBarFirstButton() -> Bool {
        let button = app.navigationBars.buttons.element(boundBy: 0)
        guard button.waitForExistence(timeout: 5), button.isHittable else { return false }
        button.tap()
        return true
    }

    /// The "..." on an exercise card. It carries no text, so it is found by its glyph or by the
    /// accessibility label the routine editor gives it.
    private func tapEllipsis() -> Bool {
        let candidates = app.buttons.allElementsBoundByIndex.filter {
            $0.isHittable && ($0.label.contains("…")
                || $0.label.lowercased().contains("ellipsis")
                || $0.label.lowercased().contains("more")
                || $0.label.lowercased().contains("options"))
        }
        guard let button = candidates.first else { return false }
        button.tap()
        return true
    }

    private func tapStopwatch() -> Bool {
        guard let button = app.buttons.allElementsBoundByIndex.first(where: {
            $0.isHittable && $0.label.contains(":")
        }) else { return false }
        button.tap()
        return true
    }

    private func tapRestTimer() -> Bool {
        // The rest timer button is the trailing one in the header row.
        let buttons = app.buttons.allElementsBoundByIndex.filter { $0.isHittable && $0.label.contains(":") }
        guard let button = buttons.last, buttons.count > 1 else { return false }
        button.tap()
        return true
    }

    private func tapMonthHeader() -> Bool {
        // The month header reads like "AUGUST 2026" and toggles the year grid.
        guard let button = app.buttons.allElementsBoundByIndex.first(where: {
            $0.isHittable && $0.label.rangeOfCharacter(from: .decimalDigits) != nil && $0.label.count < 24
        }) else { return false }
        button.tap()
        return true
    }

    // MARK: - Element helpers

    /// Taps the first hittable element whose label contains [text], trying alerts and sheets first.
    ///
    /// Exact lookups keep missing here: a menu item or an alert button is not always a plain button,
    /// and the label carries extra text as often as not. A SwiftUI .alert also puts its buttons in
    /// their own hierarchy, which app.buttons does not reach.
    @discardableResult
    private func tapFirst(in queries: [XCUIElementQuery], labelled text: String) -> Bool {
        let ordered = [app.alerts.buttons, app.sheets.buttons] + queries
        for query in ordered {
            _ = query.firstMatch.waitForExistence(timeout: 1.5)
            let match = query.allElementsBoundByIndex.first {
                $0.isHittable && $0.label.localizedCaseInsensitiveContains(text)
            }
            if let match {
                match.tap()
                return true
            }
        }
        return false
    }

    private func firstHittable(in queries: [XCUIElementQuery]) -> XCUIElement? {
        for query in queries {
            _ = query.firstMatch.waitForExistence(timeout: 3)
            if let match = query.allElementsBoundByIndex.first(where: \.isHittable) { return match }
        }
        return nil
    }

    /// Taps the nth row of whatever the screen is built from. Which element type a row is depends on
    /// how the screen was written, and these screens are not uniform, so this tries each kind and
    /// takes the first with enough hittable elements.
    @discardableResult
    private func tapRow(at index: Int, preferring queries: [XCUIElementQuery]) -> Bool {
        for query in queries {
            _ = query.firstMatch.waitForExistence(timeout: 4)
            let hittable = query.allElementsBoundByIndex.filter(\.isHittable)
            guard index < hittable.count else { continue }
            hittable[index].tap()
            return true
        }
        return false
    }

    /// Presses an alert button by label, then by role-ordered position, then by coordinate.
    ///
    /// Matching on the label alone has failed whole runs: the hierarchy captured at the failure
    /// showed no alert at all, because iOS presents it in a window these queries do not reach. The
    /// offset is the last resort and is measured off a capture, so it is recorded when used.
    private func pressAlertButton(_ label: String, fallbackOffset: CGVector) {
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 3) {
            let named = alert.buttons[label]
            if named.exists && named.isHittable {
                named.tap()
                return
            }
            // Destructive and default buttons are ordered last by iOS.
            let button = alert.buttons.element(boundBy: max(alert.buttons.count - 1, 0))
            if button.exists {
                button.tap()
                return
            }
        }
        if tapFirst(in: [app.buttons, app.staticTexts], labelled: label) { return }

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let systemButton = springboard.alerts.buttons[label]
        if systemButton.exists && systemButton.isHittable {
            systemButton.tap()
            return
        }

        note("Pressed \"\(label)\" by coordinate \(fallbackOffset): no alert in the hierarchy.")
        app.coordinate(withNormalizedOffset: fallbackOffset).tap()
    }

    /// Swipes a sheet away, or taps a Done or Cancel if one is offered.
    private func dismissSheet() {
        for label in ["Done", "Close", "Cancel"] {
            let button = app.buttons[label].firstMatch
            if button.exists && button.isHittable {
                button.tap()
                return
            }
        }
        app.swipeDown(velocity: .fast)
    }

    /// Closes a menu or a context menu by tapping the dimmed area behind it.
    private func dismissOverlay() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.04)).tap()
    }

    /// Types into [element], but only when it actually holds keyboard focus.
    ///
    /// A keyboard being on screen is not enough. Typing at an element that does not have focus raises
    /// "Failed to synthesize event: Neither element nor any descendant has keyboard focus", which is
    /// not an assertion failure and so ends the whole test method regardless of continueAfterFailure.
    /// That cost the running-workout journey every capture after the value fields. Checking focus
    /// first turns it into a skipped step.
    private func typeIfPossible(into element: XCUIElement, _ text: String) {
        guard app.keyboards.firstMatch.waitForExistence(timeout: 3) else {
            note("No software keyboard, so \"\(text)\" was not typed.")
            return
        }
        // Resolving an element that no longer matches raises, so existence is checked before anything
        // else is asked of it.
        guard element.exists else {
            note("The field went away before \"\(text)\" could be typed.")
            return
        }
        guard (element.value(forKey: "hasKeyboardFocus") as? Bool) == true else {
            note("\(element.elementType) never took keyboard focus, so \"\(text)\" was not typed.")
            return
        }
        element.typeText(text)
    }

    // MARK: - Capture

    private func launch(_ journey: String) {
        self.journey = journey
        self.step = 0
        let app = XCUIApplication()
        app.launchArguments += ["-ForgeSampleData"]
        app.launch()
        self.app = app
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 30),
            "The tab bar never appeared, so the app did not finish launching"
        )
    }

    /// [settle] lets a sheet, menu, or push finish animating. There is no element to wait on for a
    /// menu that may not exist, so this is a wait.
    private func shot(_ name: String, settle: TimeInterval = 0.6) {
        if settle > 0 { Thread.sleep(forTimeInterval: settle) }
        step += 1
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(journey)-\(String(format: "%02d", step))-\(name).png"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Files a note next to the images, so a run that missed something says what and where.
    private func note(_ message: String) {
        let attachment = XCTAttachment(string: message)
        attachment.name = "\(journey)-\(String(format: "%02d", step))-note.txt"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Records an unreachable step, with the hierarchy as it was, and carries on.
    private func skipped(_ what: String) {
        note("Could not reach \(what).\n\n\(app?.debugDescription ?? "No app.")")
    }

    private func slug(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: " & ", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "_", with: "-")
    }
}
