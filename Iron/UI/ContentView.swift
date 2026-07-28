//
//  ContentView.swift
//  Forge
//
//  Root screen: a horizontally-paged ScrollView (swipe between tabs) with the custom
//  floating dock (ForgeTabBar) overlaid. This is the reliable iOS-17 pattern for swipeable
//  pages alongside nav-heavy screens (paging TabView fights NavigationView/List): a
//  horizontal ScrollView with .scrollTargetBehavior(.paging) + .scrollPosition, two-way
//  bound to the dock's selection. Also hosts the .sqlite import flow.
//

import SwiftUI
import WorkoutDataKit

let NAVIGATION_BAR_SPACING: CGFloat = 16

struct ContentView : View {
    @EnvironmentObject private var sceneState: SceneState

    @State private var scrolledTab: SceneState.Tab?
    @State private var pendingImportURL: IdentifiableHolder<URL>?
    @State private var importResult: ImportResult?

    private struct ImportResult: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private let tabs: [SceneState.Tab] = [.feed, .history, .workout, .settings]

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.self) { tab in
                        page(for: tab)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .id(tab)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrolledTab)
            .scrollIndicators(.hidden)
            .productionEnvironment()
        }
        .background(Color.forgeBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            ForgeTabBar(selection: Binding(
                get: { sceneState.selectedTab },
                set: { select($0) }
            ))
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.xs)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if scrolledTab == nil { scrolledTab = sceneState.selectedTab }
        }
        .onChange(of: scrolledTab) { _, newValue in
            // Swiping updates the scroll position -> reflect it in the dock.
            if let newValue, newValue != sceneState.selectedTab {
                sceneState.selectedTab = newValue
            }
        }
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

    /// Dock tap -> update selection and animate the pager to that page.
    private func select(_ tab: SceneState.Tab) {
        guard tab != sceneState.selectedTab else { return }
        sceneState.selectedTab = tab
        withAnimation(.snappy(duration: 0.3)) { scrolledTab = tab }
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
