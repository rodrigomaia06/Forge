//
//  HistoryView.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 22.06.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import CoreData
import WorkoutDataKit

struct HistoryView : View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var sceneState: SceneState
    @Environment(\.managedObjectContext) var managedObjectContext
    
    @FetchRequest(fetchRequest: HistoryView.fetchRequest) var workouts

    static var fetchRequest: NSFetchRequest<Workout> {
        let request: NSFetchRequest<Workout> = Workout.fetchRequest()
        request.predicate = NSPredicate(format: "\(#keyPath(Workout.isCurrentWorkout)) != %@", NSNumber(booleanLiteral: true))
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Workout.start, ascending: false)]
        return request
    }
    
    @State private var activityItems: [Any]?

    @State private var offsetsToDelete: IndexSet?

    @State private var filterActive = false
    // Owned here and injected into the list, so the Edit/Done button can live in the header (the nav
    // bar is hidden) and still drive the list's edit mode.
    @State private var editMode: EditMode = .inactive
    @State private var fromDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var toDate = Date()

    /// Drives navigation into a workout. A typed path lets both a row tap and a deep-link from another
    /// tab push the same destination.
    @State private var path: [Workout] = []

    /// The workouts shown, filtered to the selected date range when the filter is on.
    private var displayedWorkouts: [Workout] {
        guard filterActive else { return Array(workouts) }
        let cal = Calendar.current
        let start = cal.startOfDay(for: fromDate)
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: toDate)) ?? toDate
        return workouts.filter { workout in
            guard let s = workout.start else { return false }
            return s >= start && s < end
        }
    }

    /// Returns `true` if at least one of the workouts to delete has workout exercises.
    private func needsConfirmBeforeDelete(offsets: IndexSet) -> Bool {
        let displayed = displayedWorkouts
        for index in offsets {
            if displayed[index].workoutExercises?.count ?? 0 != 0 {
                return true
            }
        }
        return false
    }

    private func deleteAt(offsets: IndexSet) {
        let displayed = displayedWorkouts
        for i in offsets.sorted().reversed() {
            displayed[i].deleteOrCrash()
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if filterActive {
                    Section(footer: Text("Showing workouts from the first to the second date.")) {
                        DatePicker("From", selection: $fromDate, in: ...toDate, displayedComponents: .date)
                        DatePicker("To", selection: $toDate, in: fromDate..., displayedComponents: .date)
                    }
                }
                ForEach(displayedWorkouts) { workout in
                    NavigationLink(value: workout) {
                        WorkoutCell(workout: workout)
                            .contextMenu {
                                // TODO add images when SwiftUI fixes the image size
                                if UIDevice.current.userInterfaceIdiom != .pad {
                                    // not working on iPad, last checked iOS 13.4
                                    Button("Share") {
                                        guard let logText = workout.logText(in: self.exerciseStore.exercises, weightUnit: self.settingsStore.weightUnit) else { return }
                                        self.activityItems = [logText]
                                    }
                                }
                                Button("Repeat") {
                                    WorkoutDetailView.repeatWorkout(workout: workout, settingsStore: self.settingsStore, sceneState: sceneState)
                                }
                                Button("Repeat (Blank)") {
                                    WorkoutDetailView.repeatWorkoutBlank(workout: workout, settingsStore: self.settingsStore, sceneState: sceneState)
                                }
                        }
                    }
                }
                .onDelete { offsets in
                    if self.needsConfirmBeforeDelete(offsets: offsets) {
                        self.offsetsToDelete = offsets
                    } else {
                        self.deleteAt(offsets: offsets)
                    }
                }
            }
            .listStyleCompat_InsetGroupedListStyle()
            .environment(\.editMode, $editMode)
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout)
                    .environmentObject(self.settingsStore)
            }
            .confirmationDialog("This cannot be undone.", isPresented: Binding(get: { offsetsToDelete != nil }, set: { if !$0 { offsetsToDelete = nil } }), titleVisibility: .visible, presenting: offsetsToDelete) { offsets in
                Button("Delete workout", role: .destructive) {
                    self.deleteAt(offsets: offsets)
                }
            }
            // The empty state is an overlay on the list, not a replacement for it. Swapping the whole
            // list out (the old .placeholder modifier) while a delete was animating tore down the list
            // mid-transaction and crashed when the last workout was removed.
            .overlay {
                if workouts.isEmpty {
                    ContentUnavailableView("No workouts yet", systemImage: "clock.arrow.circlepath", description: Text("Your finished workouts will appear here."))
                }
            }
            .forgeScreenTitle("History") {
                HStack(spacing: NAVIGATION_BAR_SPACING) {
                    Button {
                        Haptics.selection()
                        withAnimation { filterActive.toggle() }
                    } label: {
                        Image(systemName: filterActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel(filterActive ? "Hide date filter" : "Filter by date")
                    Button(editMode == .active ? "Done" : "Edit") {
                        Haptics.selection()
                        withAnimation { editMode = editMode == .active ? .inactive : .active }
                    }
                }
            }
        }
        .overlay(ActivitySheet(activityItems: self.$activityItems))
        // A deep-link from another tab (e.g. a past session tapped during a workout) lands here.
        .onChange(of: sceneState.historyWorkoutToOpen) { _ in openPendingHistoryWorkout() }
        .onAppear { openPendingHistoryWorkout() }
    }

    /// Re-roots the navigation stack at a workout requested from another tab, then clears the request.
    private func openPendingHistoryWorkout() {
        guard let workout = sceneState.historyWorkoutToOpen else { return }
        path = [workout]
        sceneState.historyWorkoutToOpen = nil
    }
}

private struct WorkoutCell: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @ObservedObject var workout: Workout

    private var durationString: String? {
        guard let duration = workout.duration else { return nil }
        return Workout.durationFormatter.string(from: duration)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(workout.displayTitle(in: self.exerciseStore.exercises, showPlan: settingsStore.showPlanInWorkoutTitle))
                    .font(.body)
                
                Text(Workout.dateFormatter.string(from: workout.start, fallback: "Unknown date"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                workout.comment.map {
                    Text($0.enquoted)
                        .lineLimit(1)
                        .font(Font.caption.italic())
                        .foregroundColor(.secondary)
                }
            }
            .layoutPriority(1)
            
            Spacer()
            
            durationString.map {
                Text($0)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder()
                            .foregroundColor(Color(.systemFill))
                    )
            }
        }
    }
}

#if DEBUG
struct HistoryView_Previews : PreviewProvider {
    static var previews: some View {
        HistoryView()
            .mockEnvironment(weightUnit: .metric)
    }
}
#endif
