//
//  SessionContentView.swift
//  SwiftUI Playground
//
//  Created by Karim Abou Zeid on 19.06.19.
//  Copyright © 2019 Karim Abou Zeid. All rights reserved.
//

import SwiftUI
import WorkoutDataKit

let NAVIGATION_BAR_SPACING: CGFloat = 16

struct ContentView : View {
    @EnvironmentObject private var sceneState: SceneState

    @State private var pendingImportURL: IdentifiableHolder<URL>?
    @State private var importResult: ImportResult?

    private struct ImportResult: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var body: some View {
        tabView
            .edgesIgnoringSafeArea([.top, .bottom])
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name.RestoreFromBackup)) { output in
                guard let url = output.userInfo?[restoreFromBackupDataUserInfoKey] as? URL else { return }
                self.pendingImportURL = IdentifiableHolder(value: url)
            }
            .alert(item: $pendingImportURL) { holder in
                Alert(
                    title: Text("Import Database?"),
                    message: Text("This replaces all workouts and exercises with the contents of this file. A safety copy of your current data is kept first. Reopen Forge afterwards to load the imported data."),
                    primaryButton: .destructive(Text("Import")) { self.importDatabase(from: holder.value) },
                    secondaryButton: .cancel()
                )
            }
            .alert(item: $importResult) { result in
                Alert(title: Text(result.title), message: Text(result.message))
            }
    }

    private func importDatabase(from url: URL) {
        do {
            try SQLiteBackup.import(from: url)
            importResult = ImportResult(title: "Import Complete", message: "Please reopen Forge to load the imported data.")
        } catch {
            importResult = ImportResult(title: "Import Failed", message: error.localizedDescription)
        }
    }
    
    @ViewBuilder
    private var tabView: some View {
        if #available(iOS 14, *) {
            TabView(selection: $sceneState.selectedTabNumber) {
                FeedView()
                    .tag(SceneState.Tab.feed.rawValue)
                    .tabItem {
                        Label("Feed", systemImage: "house")
                    }

                HistoryView()
                    .tag(SceneState.Tab.history.rawValue)
                    .tabItem {
                        Label("History", systemImage: "clock")
                    }

                WorkoutTab()
                    .tag(SceneState.Tab.workout.rawValue)
                    .tabItem {
                        Label("Workout", systemImage: "plus.diamond")
                    }

                ExerciseMuscleGroupsView()
                    .tag(SceneState.Tab.exercises.rawValue)
                    .tabItem {
                        Label("Exercises", systemImage: "tray.full")
                    }

                SettingsView()
                    .tag(SceneState.Tab.settings.rawValue)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
            .productionEnvironment()
        } else {
            /**
             *  We inject .productionEnvironment() for every tab, because when the "screen reading" accessibility setting is enabled,
             *  some Tabs get created by the system in the background without its parents environment! This is probably a bug and it happens since iOS 13.4
             */
            UITabView(viewControllers: [
                FeedView()
                    .productionEnvironment()
                    .hostingController()
                    .tabItem(title: "Feed", image: UIImage(systemName: "house"), tag: 0),

                HistoryView()
                    .productionEnvironment()
                    .hostingController()
                    .tabItem(title: "History", image: UIImage(systemName: "clock"), tag: 1),

                WorkoutTab()
                    .productionEnvironment()
                    .hostingController()
                    .tabItem(title: "Workout", image: UIImage(systemName: "plus.square"), tag: 2),

                ExerciseMuscleGroupsView()
                    .productionEnvironment()
                    .hostingController()
                    .tabItem(title: "Exercises", image: UIImage(systemName: "tray.full"), tag: 3),

                SettingsView()
                    .productionEnvironment()
                    .hostingController()
                    .tabItem(title: "Settings", image: UIImage(systemName: "gear"), tag: 4),
            ], selection: sceneState.selectedTabNumber)
        }
    }
}

private extension View {
    func productionEnvironment() -> some View {
        self
            .environmentObject(SettingsStore.shared)
            .environmentObject(RestTimerStore.shared)
            .environmentObject(ExerciseStore.shared)
            .environment(\.managedObjectContext, WorkoutDataStorage.shared.persistentContainer.viewContext)
    }
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
            .mockEnvironment(weightUnit: .metric)
    }
}
#endif
