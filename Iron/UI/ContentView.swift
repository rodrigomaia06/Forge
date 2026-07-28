//
//  ContentView.swift
//  Forge
//
//  Root screen: the selected tab's content with the custom floating dock (ForgeTabBar)
//  pinned at the bottom, on Forge's dark canvas. Also hosts the import-database flow that
//  fires when the user opens a .sqlite file.
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
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.forgeBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                ForgeTabBar(selection: Binding(
                    get: { sceneState.selectedTab },
                    set: { sceneState.selectedTab = $0 }
                ))
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.xs)
            }
            .preferredColorScheme(.dark) // Forge is dark-first (matches the design direction)
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

    @ViewBuilder private var content: some View {
        Group {
            switch sceneState.selectedTab {
            case .feed: FeedView()
            case .history: HistoryView()
            case .workout: WorkoutTab()
            case .settings: SettingsView()
            case .exercises: FeedView() // Exercises now lives inside Settings; never selected here.
            }
        }
        .productionEnvironment()
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
