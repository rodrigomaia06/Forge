//
//  ContentView.swift
//  Forge
//
//  Root screen: a standard SwiftUI TabView with the native system tab bar. Native gives reliable
//  tab switching, correct titles, and state restoration for free; the system bar is translucent,
//  so it reads as glass without any custom control. Also hosts the .sqlite import flow.
//

import SwiftUI
import WorkoutDataKit

let NAVIGATION_BAR_SPACING: CGFloat = 16

struct ContentView : View {
    @EnvironmentObject private var sceneState: SceneState
    // Observed so changing the accent in Settings re-renders and re-tints the whole app.
    @ObservedObject private var settings = SettingsStore.shared
    // Surfaces data errors from write paths that used to crash.
    @ObservedObject private var errorPresenter = AppErrorPresenter.shared

    @State private var pendingImportURL: IdentifiableHolder<URL>?
    @State private var importResult: ImportResult?

    private struct ImportResult: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private var selectedTab: Binding<SceneState.Tab> {
        Binding(get: { sceneState.selectedTab }, set: { sceneState.selectedTab = $0 })
    }

    var body: some View {
        TabView(selection: selectedTab) {
            FeedView()
                .tag(SceneState.Tab.feed)
                .tabItem { Image(systemName: "house.fill").accessibilityLabel("Home") }
            HistoryView()
                .tag(SceneState.Tab.history)
                .tabItem { Image(systemName: "clock.fill").accessibilityLabel("History") }
            WorkoutTab()
                .tag(SceneState.Tab.workout)
                .tabItem { Image(systemName: "dumbbell.fill").accessibilityLabel("Workout") }
            SettingsView()
                .tag(SceneState.Tab.settings)
                .tabItem { Image(systemName: "gearshape.fill").accessibilityLabel("Settings") }
        }
        .environmentObject(SettingsStore.shared)
        .environmentObject(RestTimerStore.shared)
        .environmentObject(ExerciseStore.shared)
        .environment(\.managedObjectContext, WorkoutDataStorage.shared.persistentContainer.viewContext)
        .tint(Color.forgeAccent) // single monochrome accent
        .preferredColorScheme((ForgeAppearance(rawValue: settings.appearance) ?? .dark).colorScheme) // Forge is dark-first; overridable in Settings
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
        .alert(item: $errorPresenter.error) { error in
            Alert(title: Text(error.title), message: Text(error.message), dismissButton: .default(Text("OK")))
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
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
            .mockEnvironment(weightUnit: .metric)
    }
}
#endif
