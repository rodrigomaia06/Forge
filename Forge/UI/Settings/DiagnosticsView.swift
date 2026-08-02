//
//  DiagnosticsView.swift
//  Forge
//
//  A compact index of locally recorded main-thread freezes. A report's full event timeline only appears
//  after it is opened, so one large trace cannot take over the whole Logs screen. Nothing leaves the
//  device unless the user explicitly exports it.
//

import SwiftUI

struct DiagnosticsView: View {
    @State private var reports: [FreezeReport] = []
    @State private var activityItems: [Any]?
    @State private var showingClearConfirmation = false

    var body: some View {
        List {
            Section {
                if reports.isEmpty {
                    ContentUnavailableView(
                        "No freezes recorded",
                        systemImage: "checkmark.circle",
                        description: Text("A report will appear here if Forge stops responding for at least three seconds.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(reports.reversed()) { report in
                        NavigationLink {
                            FreezeReportDetailView(report: report)
                        } label: {
                            FreezeReportRow(report: report)
                        }
                    }
                }
            } header: {
                if !reports.isEmpty { Text("Recorded freezes") }
            } footer: {
                Text("Reports contain fixed diagnostic event names and timings only—never workout names, exercises, entered values, notes, attributes, or identifiers. They stay on this device until you export or clear them.")
            }

            if !reports.isEmpty {
                Section {
                    Button {
                        export(reports)
                    } label: {
                        Label("Export all logs", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        Label("Clear all logs", systemImage: "trash")
                    }
                }
            }
        }
        .listStyleCompat_InsetGroupedListStyle()
        .navigationBarTitle("Logs", displayMode: .inline)
        .onAppear { reports = HangMonitor.loadReports() }
        .overlay(ActivitySheet(activityItems: $activityItems))
        .alert("Clear all logs?", isPresented: $showingClearConfirmation) {
            Button("Clear", role: .destructive) {
                HangMonitor.clearReports()
                reports = []
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes only recorded diagnostics. It does not affect your workouts.")
        }
    }

    private func export(_ reports: [FreezeReport]) {
        activityItems = FreezeLogExporter.activityItems(for: reports)
    }
}

private struct FreezeReportRow: View {
    let report: FreezeReport

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(FreezeLogFormatter.stamp.string(from: report.date))
                    .font(.forgeHeadline)
                    .foregroundColor(.forgeLabel)
                Spacer(minLength: Theme.Spacing.s)
                Text("\(report.seconds, specifier: "%.1f") s")
                    .font(.forgeValue.weight(.semibold))
                    .foregroundColor(.forgeLabel)
            }

            HStack(spacing: Theme.Spacing.xs) {
                Label("\(report.breadcrumbs.count) events", systemImage: "list.bullet.rectangle")
                if let last = report.lastResponse {
                    Text("•")
                    Text("last response \(FreezeLogFormatter.clock.string(from: last))")
                }
            }
            .font(.forgeCaption)
            .foregroundColor(.forgeSecondaryLabel)
            .lineLimit(1)
        }
        // Every report occupies one predictable, compact row regardless of the trace length.
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this freeze report")
    }
}

private struct FreezeReportDetailView: View {
    let report: FreezeReport
    @State private var activityItems: [Any]?

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Unresponsive for") {
                    Text("\(report.seconds, specifier: "%.1f") seconds")
                }
                if let last = report.lastResponse {
                    LabeledContent("Main thread last responded") {
                        Text(FreezeLogFormatter.clock.string(from: last))
                    }
                }
                LabeledContent("Recorded events") {
                    Text("\(report.breadcrumbs.count)")
                }
            }

            Section("Event timeline") {
                if report.breadcrumbs.isEmpty {
                    Text("Nothing was recorded before this freeze.")
                        .foregroundColor(.forgeSecondaryLabel)
                } else {
                    ForEach(Array(report.breadcrumbs.enumerated()), id: \.offset) { _, crumb in
                        Text(crumb)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.forgeSecondaryLabel)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Section {
                Button {
                    activityItems = FreezeLogExporter.activityItems(for: [report])
                } label: {
                    Label("Export this log", systemImage: "square.and.arrow.up")
                }
            }
        }
        .listStyleCompat_InsetGroupedListStyle()
        .navigationTitle(FreezeLogFormatter.shortStamp.string(from: report.date))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    activityItems = FreezeLogExporter.activityItems(for: [report])
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Export this log")
            }
        }
        .overlay(ActivitySheet(activityItems: $activityItems))
    }
}

/// Shared formatting for the on-screen report and the exported plain-text file.
enum FreezeLogFormatter {
    static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    static let shortStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    static func text(for reports: [FreezeReport]) -> String {
        var lines = [
            "Forge freeze log",
            "Recorded freezes: \(reports.count)",
            "Privacy: fixed diagnostic event names and timings only; no workout content or identifiers.",
            "",
        ]
        for report in reports.reversed() {
            lines.append(stamp.string(from: report.date))
            lines.append(String(format: "Unresponsive for %.1f seconds", report.seconds))
            if let last = report.lastResponse {
                lines.append("Main thread last responded at \(clock.string(from: last))")
            }
            lines.append("Recorded events: \(report.breadcrumbs.count)")
            lines.append(contentsOf: report.breadcrumbs.map { "  \($0)" })
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}

private enum FreezeLogExporter {
    private static let filenameStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    static func activityItems(for reports: [FreezeReport]) -> [Any] {
        let text = FreezeLogFormatter.text(for: reports)
        let suffix = reports.count == 1
            ? filenameStamp.string(from: reports[0].date)
            : filenameStamp.string(from: Date())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("forge-freeze-log-\(suffix).txt")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return [url]
        } catch {
            // Sharing the text itself still works when a temporary file cannot be written.
            return [text]
        }
    }
}
