//
//  ScreenshotTests.swift
//  IronTests
//
//  Renders SwiftUI views to PNGs so the UI can be reviewed without a Mac.
//  Each PNG is attached to the test result AND, when FORGE_SCREENSHOT_DIR is set
//  (passed by CI via SIMCTL_CHILD_FORGE_SCREENSHOT_DIR), written to that directory
//  so CI can upload it directly as a downloadable artifact.
//
//  As screens are restyled, add captures here (use .mockEnvironment(weightUnit:)
//  for data-driven views).
//

import XCTest
import SwiftUI
@testable import Iron

@MainActor
final class ScreenshotTests: XCTestCase {

    /// A representative iPhone width; height is intrinsic to the content.
    private let phoneWidth: CGFloat = 393

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

    // MARK: - Helpers

    private func capture<V: View>(_ view: V, named name: String) throws {
        let renderer = ImageRenderer(content:
            view.frame(width: phoneWidth)
                .environment(\.colorScheme, .dark) // Forge is dark-first
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
