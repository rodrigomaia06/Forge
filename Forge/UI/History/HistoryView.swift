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
        // Fault rows in lazily rather than materializing the whole history at once.
        request.fetchBatchSize = 20
        return request
    }
    
    @State private var activityItems: [Any]?

    @State private var workoutsToDelete: [Workout]?

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

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter
    }()

    /// Workouts grouped into month sections, newest month first and newest workout first within a month,
    /// so a long history reads as organized blocks rather than one flat scroll.
    private var monthSections: [(id: String, title: String, workouts: [Workout])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: displayedWorkouts) { workout in
            calendar.dateComponents([.year, .month], from: workout.start ?? Date.distantPast)
        }
        return groups
            .map { components, workouts -> (id: String, title: String, workouts: [Workout], sort: Date) in
                let date = calendar.date(from: components) ?? Date.distantPast
                let sorted = workouts.sorted { ($0.start ?? .distantPast) > ($1.start ?? .distantPast) }
                return ("\(components.year ?? 0)-\(components.month ?? 0)", Self.monthFormatter.string(from: date), sorted, date)
            }
            .sorted { $0.sort > $1.sort }
            .map { (id: $0.id, title: $0.title, workouts: $0.workouts) }
    }

    /// Returns `true` if at least one of the workouts to delete has workout exercises.
    private func needsConfirmBeforeDelete(_ workouts: [Workout]) -> Bool {
        workouts.contains { ($0.workoutExercises?.count ?? 0) != 0 }
    }

    private func delete(_ workouts: [Workout]) {
        for workout in workouts {
            workout.deleteOrCrash()
        }
    }

    /// Marks workouts for deletion. Empty ones go immediately; ones with logged sets wait for the
    /// confirmation alert, staying in the list (highlighted) until then, so nothing disappears early.
    private func requestDelete(_ workouts: [Workout]) {
        if needsConfirmBeforeDelete(workouts) {
            workoutsToDelete = workouts
        } else {
            delete(workouts)
        }
    }

    private var deleteMessage: String {
        guard let workouts = workoutsToDelete else { return "This cannot be undone." }
        if workouts.count == 1, let workout = workouts.first {
            let title = workout.displayTitle(in: exerciseStore.exercises, showPlan: settingsStore.showPlanInWorkoutTitle)
            return "Delete \"\(title)\"? This cannot be undone."
        }
        return "Delete \(workouts.count) workouts? This cannot be undone."
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
                ForEach(monthSections, id: \.id) { section in
                    Section(header: Text(section.title)) {
                        ForEach(section.workouts) { workout in
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
                            // Tint the row while it waits for the delete confirmation, so it is clear which
                            // workout is about to be removed. It stays in the list until Delete is confirmed.
                            .listRowBackground(workoutsToDelete?.contains(workout) == true ? Color.forgeDestructive.opacity(0.18) : nil)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    requestDelete([workout])
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(Color.forgeDestructive)
                            }
                        }
                        .onDelete { offsets in
                            requestDelete(offsets.map { section.workouts[$0] })
                        }
                    }
                }
            }
            .listStyleCompat_InsetGroupedListStyle()
            .environment(\.editMode, $editMode)
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout)
                    .environmentObject(self.settingsStore)
            }
            .alert("Delete workout?", isPresented: Binding(get: { workoutsToDelete != nil }, set: { if !$0 { workoutsToDelete = nil } })) {
                Button("Delete", role: .destructive) {
                    self.delete(self.workoutsToDelete ?? [])
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(deleteMessage)
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
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s)
                .forgeGlassCapsule()
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

    /// Exercise and set counts, matching the dashboard cards, e.g. "6 exercises · 18 sets".
    private var summaryLine: String {
        let exercises = workout.workoutExercises?.array as? [WorkoutExercise] ?? []
        let sets = exercises.reduce(0) { $0 + ($1.workoutSets?.count ?? 0) }
        return "\(exercises.count) exercises · \(sets) sets"
    }

    /// A small outlined pill, used for both the duration and the exercise/set counts.
    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder()
                    .foregroundColor(Color(.systemFill))
            )
            .fixedSize()
    }

    var body: some View {
        // Center the duration and counts against the left column (which may grow with a comment), so
        // they sit centered like the row's chevron rather than pinned to the top.
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
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

            // Duration and the exercise/set counts sit on the right as pills, so the comment has the
            // left column to itself and the row stays compact.
            VStack(alignment: .trailing, spacing: 4) {
                durationString.map { pill($0) }
                pill(summaryLine)
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
