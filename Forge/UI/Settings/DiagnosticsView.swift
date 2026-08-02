//
//  DiagnosticsView.swift
//  Forge
//
//  Shows what HangMonitor recorded when the app stopped responding, and lets the user send it on.
//  Nothing here leaves the device unless the user shares it.
//

import SwiftUI

struct DiagnosticsView: View {
    @State private var reports: [FreezeReport] = []
    @State private var activityItems: [Any]?
    @State private var showingClearConfirmation = false

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    var body: some View {
        List {
            Section(footer: Text("Forge watches its own main thread. If the app stops responding for more than a few seconds, it records when that happened, how long it lasted, and the interactions just before it. Only the names of actions are kept, never your workouts, values, or notes. Nothing is sent anywhere.")) {
                if reports.isEmpty {
                    Text("No freezes recorded.")
                        .foregroundColor(.forgeSecondaryLabel)
                }
            }

            ForEach(reports.reversed()) { report in
                Section(header: Text(Self.stamp.string(from: report.date))) {
                    LabeledContent("Unresponsive for") {
                        Text("\(report.seconds, specifier: "%.1f") seconds")
                    }
                    if let last = report.lastResponse {
                        LabeledContent("Last responded") {
                            Text(Self.clock.string(from: last))
                        }
                    }
                    if report.breadcrumbs.isEmpty {
                        Text("Nothing recorded before it.")
                            .font(.forgeCaption)
                            .foregroundColor(.forgeSecondaryLabel)
                    } else {
                        ForEach(Array(report.breadcrumbs.enumerated()), id: \.offset) { _, crumb in
                            Text(crumb)
                                .font(.forgeCaption.monospaced())
                                .foregroundColor(.forgeSecondaryLabel)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if !reports.isEmpty {
                Section {
                    Button("Export logs") { export() }
                    Button("Clear logs", role: .destructive) { showingClearConfirmation = true }
                }
            }
        }
        .listStyleCompat_InsetGroupedListStyle()
        .navigationBarTitle("Logs", displayMode: .inline)
        .onAppear { reports = HangMonitor.loadReports() }
        .overlay(ActivitySheet(activityItems: $activityItems))
        .alert("Clear logs?", isPresented: $showingClearConfirmation) {
            Button("Clear", role: .destructive) {
                HangMonitor.clearReports()
                reports = []
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the recorded freezes. It does not affect your workouts.")
        }
    }

    /// Written as a plain text file, so it can be read anywhere it is sent.
    private func export() {
        var lines = ["Forge freeze log", "Recorded freezes: \(reports.count)", ""]
        for report in reports.reversed() {
            lines.append(Self.stamp.string(from: report.date))
            lines.append(String(format: "Unresponsive for %.1f seconds", report.seconds))
            if let last = report.lastResponse {
                lines.append("Main thread last responded at \(Self.clock.string(from: last))")
            }
            lines.append(contentsOf: report.breadcrumbs.map { "  \($0)" })
            lines.append("")
        }
        let text = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("forge-freeze-log.txt")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            activityItems = [url]
        } catch {
            // Sharing the text itself still works when the file cannot be written.
            activityItems = [text]
        }
    }
}
