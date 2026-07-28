//
//  ContentView.swift
//  Forge
//
//  Root screen: a reliably swipeable pager (SwipeTabView / UIPageViewController) with the
//  custom floating dock (ForgeTabBar) overlaid so page content sits behind it — that's what
//  gives the dock real frosted glass. Also hosts the .sqlite import flow.
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

    private let tabs: [SceneState.Tab] = [.feed, .history, .workout, .settings]
    /// Room reserved inside each page (above the home indicator) so content clears the dock.
    private let dockInset: CGFloat = 64

    var body: some View {
        ZStack(alignment: .bottom) {
            SwipeTabView(
                selection: Binding(
                    get: { tabs.firstIndex(of: sceneState.selectedTab) ?? 0 },
                    set: { sceneState.selectedTab = tabs[$0] }
                ),
                bottomInset: dockInset,
                pages: tabs.map { tab in
                    AnyView(
                        page(for: tab)
                            .environmentObject(SettingsStore.shared)
                            .environmentObject(RestTimerStore.shared)
                            .environmentObject(ExerciseStore.shared)
                            .environmentObject(sceneState)
                            .environment(\.managedObjectContext, WorkoutDataStorage.shared.persistentContainer.viewContext)
                    )
                }
            )
            .ignoresSafeArea()

            ForgeTabBar(selection: Binding(
                get: { sceneState.selectedTab },
                set: { sceneState.selectedTab = $0 }
            ))
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xs)
        }
        .background(Color.forgeBackground.ignoresSafeArea())
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

    @ViewBuilder private func page(for tab: SceneState.Tab) -> some View {
        switch tab {
        case .feed: FeedView()
        case .history: HistoryView()
        case .workout: WorkoutTab()
        case .settings: SettingsView()
        case .exercises: EmptyView() // Exercises lives inside Settings; not a page.
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
