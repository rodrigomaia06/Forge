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

    @State private var showExportWorkoutDataSheet = false
    @State private var showImporter = false
    @State private var showJSONImporter = false
    @State private var activityItems: [Any]?
    @State private var message: Message?

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
                header: Text("Database".uppercased()),
                footer: Text("The database is a standard SQLite file you can open and edit in any SQLite tool. Importing replaces all current data — a safety copy is kept first, and you'll need to reopen Forge afterwards.")
            ) {
                Button("Export Database") { exportDatabase() }
                Button("Import Database") { showImporter = true }
            }

            Section(header: Text("Export".uppercased())) {
                Button("Workout Data") { showExportWorkoutDataSheet = true }
            }

            Section(
                header: Text("Share".uppercased()),
                footer: Text("Import a workout or plan someone shared as a JSON file. It is added to your data with new identifiers, so it never overwrites what you already have. Share a plan from the plan's screen, or a workout from its page in History.")
            ) {
                Button("Import from file") { showJSONImporter = true }
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
            case .success(let url): importJSON(from: url)
            case .failure(let error): message = Message(title: "Import failed", text: error.localizedDescription)
            }
        }
        .confirmationDialog("Workout data", isPresented: $showExportWorkoutDataSheet, titleVisibility: .visible) {
            Button("JSON") {
                guard let workouts = self.fetchWorkouts() else { return }

                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
                encoder.dateEncodingStrategy = .iso8601
                if let exercisesKey = CodingUserInfoKey.exercisesKey {
                    encoder.userInfo[exercisesKey] = ExerciseStore.shared.exercises
                }

                guard let data = try? encoder.encode(workouts) else { return }
                guard let url = try? self.tempFile(data: data, name: "workout_data.json") else { return }
                self.shareFile(url: url)
            }
            Button("TXT") {
                guard let workouts = self.fetchWorkouts() else { return }

                let text = workouts.compactMap { $0.logText(in: self.exerciseStore.exercises, weightUnit: self.settingsStore.weightUnit) }.joined(separator: "\n\n\n\n\n")

                guard let data = text.data(using: .utf8) else { return }
                guard let url = try? self.tempFile(data: data, name: "workout_data.txt") else { return }
                self.shareFile(url: url)
            }
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

    private func importJSON(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let result = try WorkoutDataExchange.import(data, into: managedObjectContext)
            var parts: [String] = []
            if result.plans > 0 { parts.append(result.plans == 1 ? "1 plan" : "\(result.plans) plans") }
            if result.workouts > 0 { parts.append(result.workouts == 1 ? "1 workout" : "\(result.workouts) workouts") }
            message = Message(title: "Import complete", text: "Added \(parts.joined(separator: " and ")).")
        } catch {
            os_log("Could not import JSON: %@", log: .backup, type: .error, error.localizedDescription)
            message = Message(title: "Import failed", text: (error as? LocalizedError)?.errorDescription ?? "This file could not be read.")
        }
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
