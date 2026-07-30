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

    @State private var importPreview: ImportPreview?
    @State private var importResult: ImportResult?

    private struct ImportResult: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    /// A validated, inspected backup awaiting the user's confirmation to replace the live store.
    private struct ImportPreview: Identifiable {
        let id = UUID()
        let url: URL
        let summary: SQLiteBackup.ImportSummary
    }

    private var selectedTab: Binding<SceneState.Tab> {
        Binding(get: { sceneState.selectedTab }, set: { sceneState.selectedTab = $0 })
    }

    private static let tabs: [(tab: SceneState.Tab, icon: String, label: String)] = [
        (.feed, "house.fill", "Home"),
        (.history, "clock.fill", "History"),
        (.workout, "dumbbell.fill", "Workout"),
        (.settings, "gearshape.fill", "Settings"),
    ]

    /// Custom bottom bar, since the page tab style hides the system one. Tapping still switches tabs.
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Self.tabs, id: \.tab) { item in
                Button {
                    Haptics.selection()
                    withAnimation(.easeInOut(duration: 0.2)) { sceneState.selectedTab = item.tab }
                } label: {
                    Image(systemName: item.icon)
                        .font(.system(size: 22))
                        .foregroundColor(sceneState.selectedTab == item.tab ? .forgeAccent : .forgeSecondaryLabel)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityLabel(item.label)
                        .accessibilityAddTraits(sceneState.selectedTab == item.tab ? [.isSelected] : [])
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 6)
        .background(.bar)
    }

    var body: some View {
        TabView(selection: selectedTab) {
            FeedView().tag(SceneState.Tab.feed)
            HistoryView().tag(SceneState.Tab.history)
            WorkoutTab().tag(SceneState.Tab.workout)
            SettingsView().tag(SceneState.Tab.settings)
        }
        // Swipe left/right to move between tabs (the Instagram pattern), with a custom bar since the page
        // style hides the system one. UIKit's paging arbitrates against a list row's swipe-to-delete better
        // than a raw gesture would.
        .tabViewStyle(.page(indexDisplayMode: .never))
        .safeAreaInset(edge: .bottom) { tabBar }
        .environmentObject(SettingsStore.shared)
        .environmentObject(RestTimerStore.shared)
        .environmentObject(ExerciseStore.shared)
        .environment(\.managedObjectContext, WorkoutDataStorage.shared.persistentContainer.viewContext)
        .tint(Color.forgeAccent) // single monochrome accent
        .dismissesKeyboardOnBackgroundTap()
        .preferredColorScheme((ForgeAppearance(rawValue: settings.appearance) ?? .dark).colorScheme) // Forge is dark-first; overridable in Settings
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.RestoreFromBackup)) { output in
            guard let url = output.userInfo?[restoreFromBackupDataUserInfoKey] as? URL else { return }
            // Validate and inspect before offering the destructive replace, so a bad or duplicate-laden
            // file is rejected up front and the user sees what the backup contains.
            do {
                let summary = try SQLiteBackup.inspect(from: url)
                self.importPreview = ImportPreview(url: url, summary: summary)
            } catch {
                self.importResult = ImportResult(title: "Import failed", message: (error as? LocalizedError)?.errorDescription ?? "This file could not be read.")
            }
        }
        .alert(item: $importPreview) { preview in
            Alert(
                title: Text("Import backup?"),
                message: Text("This replaces your current data with the backup: \(preview.summary.workouts) workouts, \(preview.summary.routines) routines, \(preview.summary.customExercises) custom exercises. A safety copy of your current data is kept first. Reopen Forge afterwards to load it."),
                primaryButton: .destructive(Text("Import")) { self.importDatabase(from: preview.url) },
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
            importResult = ImportResult(title: "Import complete", message: "Reopen Forge to load the imported data.")
        } catch {
            importResult = ImportResult(title: "Import failed", message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
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
