//
//  BackupAndExportView.swift
//  Forge
//
//  Created by Karim Abou Zeid on 17.09.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import CoreData
import WorkoutDataKit
import UniformTypeIdentifiers
import os.log

struct BackupAndExportView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var exerciseStore: ExerciseStore

    @State private var showImporter = false
    @State private var showJSONImporter = false
    @State private var showResetConfirm = false
    @State private var pendingJSONImport: PendingJSONImport?
    @State private var activityItems: [Any]?
    @State private var message: Message?

    /// A validated JSON file awaiting the user's confirmation to import.
    private struct PendingJSONImport: Identifiable {
        let id = UUID()
        let data: Data
        let summary: WorkoutDataExchange.ImportResult
    }

    private struct Message: Identifiable {
        let id = UUID()
        let title: String
        let text: String
    }

    private static var databaseTypes: [UTType] {
        [UTType(filenameExtension: "sqlite"), UTType("public.database"), .data].compactMap { $0 }
    }

    var body: some View {
        Form {
            Section(
                header: Text("Database"),
                footer: Text("The database is a standard SQLite file you can open and edit in any SQLite tool. Importing replaces all current data — a safety copy is kept first, and you'll need to reopen Forge afterwards.")
            ) {
                Button("Export Database") { exportDatabase() }
                Button("Import Database") { showImporter = true }
            }

            Section(header: Text("Export")) {
                Menu("Workout Data") {
                    Button("Export as JSON") { exportWorkoutData(asJSON: true) }
                    Button("Export as text") { exportWorkoutData(asJSON: false) }
                }
            }

            Section(
                header: Text("Share"),
                footer: Text("Import a JSON file someone shared. Plans and routines are added, and any workouts in the file are added to your History. Everything comes in with new identifiers, so it never overwrites what you already have. You'll see what a file contains before it's imported.")
            ) {
                Button("Import from file") { showJSONImporter = true }
            }

            Section(
                header: Text("Reset"),
                footer: Text("Removes all workouts, routines, plans, and custom exercises, returning Forge to a clean state. The built-in exercises remain. Export a backup first if you might want your data later.")
            ) {
                Button("Reset all data", role: .destructive) { showResetConfirm = true }
            }
        }
        .navigationBarTitle("Backup & Export", displayMode: .inline)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: Self.databaseTypes) { result in
            switch result {
            case .success(let url): importDatabase(from: url)
            case .failure(let error): message = Message(title: "Import Failed", text: error.localizedDescription)
            }
        }
        .fileImporter(isPresented: $showJSONImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): prepareJSONImport(from: url)
            case .failure(let error): message = Message(title: "Import failed", text: error.localizedDescription)
            }
        }
        .alert("Import this file?", isPresented: Binding(get: { pendingJSONImport != nil }, set: { if !$0 { pendingJSONImport = nil } }), presenting: pendingJSONImport) { pending in
            Button(pending.summary.workouts > 0 ? "Add to data and History" : "Add to my data") {
                confirmJSONImport(pending)
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {}
        } message: { pending in
            Text(Self.importWarning(for: pending.summary))
        }
        .alert("Reset all data?", isPresented: $showResetConfirm) {
            Button("Reset everything", role: .destructive) { resetAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes all workouts, routines, plans, and custom exercises. The built-in exercises remain. This cannot be undone.")
        }
        .alert(item: $message) { message in
            Alert(title: Text(message.title), message: Text(message.text))
        }
        .overlay(ActivitySheet(activityItems: $activityItems))
    }

    private func exportDatabase() {
        do {
            os_log("Exporting database", log: .backup, type: .default)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(SQLiteBackup.suggestedExportName())
            try SQLiteBackup.export(to: url)
            shareFile(url: url)
        } catch {
            os_log("Could not export database: %@", log: .backup, type: .error, error.localizedDescription)
            message = Message(title: "Could Not Export", text: error.localizedDescription)
        }
    }

    private func importDatabase(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            // Copy to a location we own before replacing the store.
            let local = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(SQLiteBackup.fileExtension)
            try? FileManager.default.removeItem(at: local)
            try FileManager.default.copyItem(at: url, to: local)

            try SQLiteBackup.import(from: local)
            message = Message(title: "Import Complete", text: "Please reopen Forge to load the imported data.")
        } catch {
            os_log("Could not import database: %@", log: .backup, type: .error, error.localizedDescription)
            message = Message(title: "Import Failed", text: error.localizedDescription)
        }
    }

    /// Delete all user-created data, returning Forge to a clean state. The built-in exercise catalog is
    /// loaded from the bundle, not the store, so it remains.
    private func resetAllData() {
        for name in ["Workout", "WorkoutPlan", "WorkoutRoutine", "CustomExercise", "ExerciseSettings"] {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: name)
            if let objects = try? managedObjectContext.fetch(request) as? [NSManagedObject] {
                objects.forEach { managedObjectContext.delete($0) }
            }
        }
        do {
            try managedObjectContext.save()
            message = Message(title: "Data reset", text: "All workouts, routines, plans, and custom exercises were removed.")
        } catch {
            os_log("Could not reset data: %@", log: .backup, type: .error, error.localizedDescription)
            message = Message(title: "Reset failed", text: error.localizedDescription)
        }
    }

    private func exportWorkoutData(asJSON: Bool) {
        guard let workouts = fetchWorkouts() else { return }
        do {
            let url: URL
            if asJSON {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
                encoder.dateEncodingStrategy = .iso8601
                if let exercisesKey = CodingUserInfoKey.exercisesKey {
                    encoder.userInfo[exercisesKey] = ExerciseStore.shared.exercises
                }
                url = try tempFile(data: try encoder.encode(workouts), name: "workout_data.json")
            } else {
                let text = workouts.compactMap { $0.logText(in: exerciseStore.exercises, weightUnit: settingsStore.weightUnit, fallbackBodyweight: settingsStore.bodyweight) }.joined(separator: "\n\n\n\n\n")
                url = try tempFile(data: Data(text.utf8), name: "workout_data.txt")
            }
            shareFile(url: url)
        } catch {
            message = Message(title: "Export failed", text: error.localizedDescription)
        }
    }

    /// Read and validate the file, then show a confirmation describing what it will add.
    private func prepareJSONImport(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let summary = try WorkoutDataExchange.summary(data)
            pendingJSONImport = PendingJSONImport(data: data, summary: summary)
        } catch {
            os_log("Could not read JSON import: %@", log: .backup, type: .error, error.localizedDescription)
            message = Message(title: "Import failed", text: (error as? LocalizedError)?.errorDescription ?? "This file could not be read.")
        }
    }

    private func confirmJSONImport(_ pending: PendingJSONImport) {
        do {
            let result = try WorkoutDataExchange.import(pending.data, into: managedObjectContext, includeWorkouts: true)
            message = Message(title: "Import complete", text: "Added \(Self.countsPhrase(for: result)).")
        } catch {
            os_log("Could not import JSON: %@", log: .backup, type: .error, error.localizedDescription)
            message = Message(title: "Import failed", text: (error as? LocalizedError)?.errorDescription ?? "This file could not be imported.")
        }
    }

    /// "2 plans, 3 routines and 15 workouts" — used in the warning and the result.
    private static func countsPhrase(for r: WorkoutDataExchange.ImportResult) -> String {
        var parts: [String] = []
        if r.plans > 0 { parts.append(r.plans == 1 ? "1 plan" : "\(r.plans) plans") }
        if r.routines > 0 { parts.append(r.routines == 1 ? "1 routine" : "\(r.routines) routines") }
        if r.workouts > 0 { parts.append(r.workouts == 1 ? "1 workout" : "\(r.workouts) workouts") }
        guard !parts.isEmpty else { return "nothing" }
        if parts.count == 1 { return parts[0] }
        return parts.dropLast().joined(separator: ", ") + " and " + parts.last!
    }

    private static func importWarning(for r: WorkoutDataExchange.ImportResult) -> String {
        var text = "This adds \(countsPhrase(for: r)) with new identifiers. It won't change or overwrite your existing data."
        if r.workouts > 0 {
            text += r.workouts == 1 ? " The workout is added to your History." : " The workouts are added to your History."
        }
        return text
    }

    private func fetchWorkouts() -> [Workout]? {
        let request: NSFetchRequest<Workout> = Workout.fetchRequest()
        request.predicate = NSPredicate(format: "\(#keyPath(Workout.isCurrentWorkout)) != %@", NSNumber(booleanLiteral: true))
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Workout.start, ascending: false)]
        return (try? self.managedObjectContext.fetch(request))
    }

    private func tempFile(data: Data, name: String) throws -> URL {
        let path = FileManager.default.temporaryDirectory
        let url = path.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    private func shareFile(url: URL) {
        self.activityItems = [url]
    }
}

#if DEBUG
struct BackupAndExportView_Previews: PreviewProvider {
    static var previews: some View {
        BackupAndExportView()
            .mockEnvironment(weightUnit: .metric)
    }
}
#endif
