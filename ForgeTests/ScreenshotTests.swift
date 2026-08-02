//
//  ScreenshotTests.swift
//  IronTests
//
//  Renders SwiftUI views to PNGs so the UI can be reviewed without a Mac.
//  Each PNG is attached to the test result AND, when FORGE_SCREENSHOT_DIR is set
//  (passed by CI via SIMCTL_CHILD_FORGE_SCREENSHOT_DIR), written to that directory
//  so CI can upload it directly as a downloadable artifact.
//
//  These are the reference the Dart rewrite is built against, which is why the
//  set covers whole screens and not only components. They use
//  screenshotEnvironment rather than mockEnvironment: the latter seeds random
//  data, so two runs would differ and a comparison between them would mean
//  nothing.
//
//  As screens are restyled, add captures here.
//

import XCTest
import SwiftUI
@testable import Forge

@MainActor
final class ScreenshotTests: XCTestCase {

    /// A representative iPhone width; height is intrinsic to the content.
    private let phoneWidth: CGFloat = 393

    /// Tall enough for a whole screen. A List or a ScrollView has no intrinsic
    /// height worth rendering, so a full screen has to be given one.
    private let phoneHeight: CGFloat = 852

    func testCaptureStyleGuide() throws {
        try capture(StyleGuide(), named: "style-guide")
    }

    func testCaptureSetRows() throws {
        try capture(ForgeSetRowGallery(), named: "set-rows")
    }

    func testCaptureExerciseView() throws {
        try capture(ForgeExerciseView(), named: "exercise-view")
    }

    func testCaptureHome() throws {
        try capture(ForgeHomeView(), named: "home")
    }

    // MARK: - Whole screens

    /// The app as it opens, tab bar and all.
    func testCaptureContentView() throws {
        try captureScreen(
            ContentView().screenshotEnvironment(weightUnit: .metric),
            named: "content"
        )
    }

    func testCaptureFeed() throws {
        try captureScreen(
            FeedView().screenshotEnvironment(weightUnit: .metric),
            named: "feed"
        )
    }

    func testCaptureHistory() throws {
        try captureScreen(
            NavigationStack { HistoryView() }
                .screenshotEnvironment(weightUnit: .metric),
            named: "history"
        )
    }

    func testCaptureWorkoutTab() throws {
        try captureScreen(
            NavigationStack { WorkoutTab() }
                .screenshotEnvironment(weightUnit: .metric),
            named: "workout-tab"
        )
    }

    func testCaptureSettings() throws {
        try captureScreen(
            NavigationStack { SettingsView() }
                .screenshotEnvironment(weightUnit: .metric),
            named: "settings"
        )
    }

    func testCaptureGeneralSettings() throws {
        try captureScreen(
            NavigationStack { GeneralSettingsView() }
                .screenshotEnvironment(weightUnit: .metric),
            named: "settings-general"
        )
    }

    func testCaptureBackupAndExport() throws {
        try captureScreen(
            NavigationStack { BackupAndExportView() }
                .screenshotEnvironment(weightUnit: .metric),
            named: "settings-backup"
        )
    }

    func testCaptureAbout() throws {
        try captureScreen(NavigationStack { AboutView() }, named: "settings-about")
    }

    func testCaptureExercises() throws {
        try captureScreen(
            NavigationStack {
                ExercisesView(exercises: ExerciseStore.shared.shownExercises)
            }
            .screenshotEnvironment(weightUnit: .metric),
            named: "exercises"
        )
    }

    func testCaptureRestTimer() throws {
        try captureScreen(
            RestTimerView().environmentObject(RestTimerStore.shared),
            named: "rest-timer"
        )
    }

    /// One screen in light, to check the palette holds up. Forge is dark-first,
    /// so the rest of the set stays dark rather than doubling in size.
    func testCaptureContentViewLight() throws {
        try captureScreen(
            ContentView().screenshotEnvironment(weightUnit: .metric),
            named: "content-light",
            colorScheme: .light
        )
    }

    /// Imperial reads differently and the layout has to survive the longer
    /// numbers.
    func testCaptureHistoryImperial() throws {
        try captureScreen(
            NavigationStack { HistoryView() }
                .screenshotEnvironment(weightUnit: .imperial),
            named: "history-imperial"
        )
    }

    // MARK: - Helpers

    /// A whole screen, at phone size.
    private func captureScreen<V: View>(
        _ view: V,
        named name: String,
        colorScheme: ColorScheme = .dark
    ) throws {
        try capture(
            view.frame(height: phoneHeight),
            named: name,
            colorScheme: colorScheme
        )
    }

    private func capture<V: View>(
        _ view: V,
        named name: String,
        colorScheme: ColorScheme = .dark
    ) throws {
        let renderer = ImageRenderer(content:
            view.frame(width: phoneWidth)
                .environment(\.colorScheme, colorScheme) // Forge is dark-first
        )
        renderer.scale = 3

        guard let image = renderer.uiImage, let data = image.pngData() else {
            XCTFail("Could not render screenshot '\(name)'")
            return
        }

        // Always attach to the test result bundle.
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = "\(name).png"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Also write straight to disk when CI provides an output directory.
        if let dir = ProcessInfo.processInfo.environment["FORGE_SCREENSHOT_DIR"], !dir.isEmpty {
            let dirURL = URL(fileURLWithPath: dir, isDirectory: true)
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            try data.write(to: dirURL.appendingPathComponent("\(name).png"))
        }
    }
}
