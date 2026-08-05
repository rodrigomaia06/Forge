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
    @State private var path: [NSManagedObjectID] = []
    @State private var historySections: [HistorySection] = []

    private struct WorkoutSnapshotInput: Equatable {
        let objectURI: URL
        let start: Date?
    }

    fileprivate struct HistorySection: Identifiable {
        let id: String
        let title: String
        let workouts: [HistoryRow]
    }

    fileprivate struct HistoryRow: Identifiable, Hashable {
        let objectID: NSManagedObjectID
        let start: Date?
        let title: String
        let dateText: String
        let durationText: String?
        let summaryLine: String

        var id: NSManagedObjectID { objectID }
    }

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

    private static let weekRangeFormatter: DateIntervalFormatter = {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var workoutSnapshotInputs: [WorkoutSnapshotInput] {
        workouts.map { WorkoutSnapshotInput(objectURI: $0.objectID.uriRepresentation(), start: $0.start) }
    }

    /// Workouts grouped into week sections, built from value snapshots so body rendering does not regroup
    /// Core Data objects or walk relationships for each row.
    private func makeHistorySections() -> [HistorySection] {
        var calendar = Calendar.current
        calendar.firstWeekday = settingsStore.firstWeekday
        let groups = Dictionary(grouping: displayedWorkouts.map { makeHistoryRow(for: $0) }) { row in
            calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: row.start ?? Date.distantPast)
        }
        return groups
            .map { components, workouts -> (id: String, title: String, workouts: [HistoryRow], sort: Date) in
                let sorted = workouts.sorted { ($0.start ?? .distantPast) > ($1.start ?? .distantPast) }
                let newest = sorted.first?.start ?? Date.distantPast
                let oldest = sorted.last?.start ?? newest
                let title = Self.weekRangeFormatter.string(from: oldest, to: newest)
                return ("\(components.yearForWeekOfYear ?? 0)-\(components.weekOfYear ?? 0)", title, sorted, newest)
            }
            .sorted { $0.sort > $1.sort }
            .map { HistorySection(id: $0.id, title: $0.title, workouts: $0.workouts) }
    }

    private func makeHistoryRow(for workout: Workout) -> HistoryRow {
        let exercises = workout.workoutExercises?.array as? [WorkoutExercise] ?? []
        let sets = exercises.reduce(0) { $0 + ($1.workoutSets?.count ?? 0) }
        return HistoryRow(
            objectID: workout.objectID,
            start: workout.start,
            title: workout.displayTitle(in: exerciseStore.exercises, showPlan: settingsStore.showPlanInWorkoutTitle),
            dateText: Workout.dateFormatter.string(from: workout.start, fallback: "Unknown date"),
            durationText: workout.duration.flatMap { Workout.durationFormatter.string(from: $0) },
            summaryLine: "\(exercises.count) exercises · \(sets) sets"
        )
    }

    private func rebuildHistorySections() {
        historySections = makeHistorySections()
    }

    private func workout(for objectID: NSManagedObjectID) -> Workout? {
        (try? managedObjectContext.existingObject(with: objectID)) as? Workout
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

    private func requestDelete(_ rows: [HistoryRow]) {
        requestDelete(rows.compactMap { workout(for: $0.objectID) })
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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    if filterActive {
                        filterSection
                    }
                    ForEach(historySections) { section in
                        historySection(section)
                    }
                }
                .padding(.horizontal, Theme.Layout.insetGroupedRowInset)
                .padding(.top, Theme.Spacing.m)
                .padding(.bottom, Theme.Layout.bottomScrollClearance)
            }
            .background(Color.forgeBackground.ignoresSafeArea())
            .navigationDestination(for: NSManagedObjectID.self) { objectID in
                if let workout = workout(for: objectID) {
                    // Opened from an editing list, the workout opens editable too.
                    WorkoutDetailView(workout: workout, initialEditMode: editMode)
                        .environmentObject(self.settingsStore)
                } else {
                    ContentUnavailableView("Workout unavailable", systemImage: "exclamationmark.circle", description: Text("This workout could not be opened."))
                }
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
        .onChange(of: workoutSnapshotInputs) { _, _ in rebuildHistorySections() }
        .onChange(of: filterActive) { _, _ in rebuildHistorySections() }
        .onChange(of: fromDate) { _, _ in rebuildHistorySections() }
        .onChange(of: toDate) { _, _ in rebuildHistorySections() }
        .onChange(of: settingsStore.firstWeekday) { _, _ in rebuildHistorySections() }
        .onChange(of: settingsStore.showPlanInWorkoutTitle) { _, _ in rebuildHistorySections() }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: managedObjectContext)) { _ in
            rebuildHistorySections()
        }
        .onAppear {
            rebuildHistorySections()
            openPendingHistoryWorkout()
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(spacing: 0) {
                DatePicker("From", selection: $fromDate, in: ...toDate, displayedComponents: .date)
                    .padding(.horizontal, Theme.Layout.insetGroupedRowInset)
                    .frame(minHeight: Theme.Layout.minTapTarget)
                ForgeListSeparator().padding(.horizontal, Theme.Layout.insetGroupedRowInset)
                DatePicker("To", selection: $toDate, in: fromDate..., displayedComponents: .date)
                    .padding(.horizontal, Theme.Layout.insetGroupedRowInset)
                    .frame(minHeight: Theme.Layout.minTapTarget)
            }
            .background(Color.forgeSurface)

            Text("Showing workouts from the first to the second date.")
                .font(.forgeCaption)
                .foregroundColor(.forgeSecondaryLabel)
                .padding(.horizontal, Theme.Layout.insetGroupedRowInset)
        }
    }

    private func historySection(_ section: HistorySection) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text(section.title)
                .font(.title3.weight(.semibold))
                .foregroundColor(.forgeSecondaryLabel)
                .padding(.horizontal, Theme.Layout.insetGroupedRowInset)

            VStack(spacing: 0) {
                ForEach(Array(section.workouts.enumerated()), id: \.element.id) { index, workout in
                    historyRow(workout)
                    if index < section.workouts.count - 1 {
                        ForgeListSeparator().padding(.horizontal, Theme.Layout.insetGroupedRowInset)
                    }
                }
            }
            .forgeCard()
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        }
    }

    private func historyRow(_ row: HistoryRow) -> some View {
        ForgeSwipeToDeleteRow(deleteAccessibilityLabel: "Delete workout", onDelete: { requestDelete([row]) }) {
            Button {
                path.append(row.objectID)
            } label: {
                WorkoutCell(workout: row)
                    .padding(.horizontal, Theme.Layout.insetGroupedRowInset)
                    .frame(minHeight: 74)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(workoutsToDelete?.contains(where: { $0.objectID == row.objectID }) == true ? Color.forgeDestructive.opacity(0.18) : Color.forgeSurface)
            .contextMenu {
                // TODO add images when SwiftUI fixes the image size
                if UIDevice.current.userInterfaceIdiom != .pad {
                    // not working on iPad, last checked iOS 13.4
                    Button("Share") {
                        guard let workout = self.workout(for: row.objectID),
                              let logText = workout.logText(in: self.exerciseStore.exercises, weightUnit: self.settingsStore.weightUnit, fallbackBodyweight: self.settingsStore.bodyweight) else { return }
                        self.activityItems = [logText]
                    }
                }
                Button("Repeat") {
                    guard let workout = self.workout(for: row.objectID) else { return }
                    WorkoutDetailView.repeatWorkout(workout: workout, settingsStore: self.settingsStore, sceneState: sceneState)
                }
                Button("Repeat (Blank)") {
                    guard let workout = self.workout(for: row.objectID) else { return }
                    WorkoutDetailView.repeatWorkoutBlank(workout: workout, settingsStore: self.settingsStore, sceneState: sceneState)
                }
                Button(role: .destructive) {
                    requestDelete([row])
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    /// Re-roots the navigation stack at a workout requested from another tab, then clears the request.
    private func openPendingHistoryWorkout() {
        guard let workout = sceneState.historyWorkoutToOpen else { return }
        path = [workout.objectID]
        sceneState.historyWorkoutToOpen = nil
    }
}

private struct WorkoutCell: View {
    let workout: HistoryView.HistoryRow

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
        HStack(alignment: .center, spacing: Theme.Spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.title)
                    .font(.body)
                    .foregroundColor(.forgeLabel)

                Text(workout.dateText)
                    .font(.caption)
                    .foregroundColor(.forgeSecondaryLabel)
            }
            .layoutPriority(1)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                workout.durationText.map { pill($0) }
                pill(workout.summaryLine)
            }

            Image(systemName: "chevron.right")
                .font(.body.weight(.semibold))
                .foregroundColor(.forgeSecondaryLabel)
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
