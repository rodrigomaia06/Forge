//
//  CurrentWorkoutView.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 19.07.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import AVKit
import WorkoutDataKit
import os.log

struct CurrentWorkoutView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    // Owned here (not read from the environment) and injected into the List below, so the Edit/Done
    // toggle and the reorder view stay in sync — the ambient editMode is a different scope.
    @State private var editMode: EditMode = .inactive
    @EnvironmentObject var restTimerStore: RestTimerStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var sceneState: SceneState
    
    @ObservedObject var workout: Workout
    
    @State private var showingCancelActionSheet = false
    @State private var showingFinishConfirmation = false
    /// Set when finishing a workout whose structure no longer matches its routine, to offer updating it.
    @State private var routineUpdatePending: WorkoutRoutine?
    @State private var showingCannotFinish = false
    @State private var activeSheet: SheetType?
    
    private enum SheetType: Identifiable {
        case exerciseSelector

        var id: Self { self }
    }
    
    private func sheetView(type: SheetType) -> AnyView {
        switch type {
        case .exerciseSelector:
            return AddExercisesSheet(
                exercises: exerciseStore.shownExercises,
                recentExercises: AddExercisesSheet.loadRecentExercises(context: managedObjectContext, exercises: exerciseStore.shownExercises),
                onAdd: { selection in self.addExercises(Array(selection), asSuperset: false) },
                onAddSuperset: { ordered in self.addExercises(ordered, asSuperset: true) }
            ).typeErased
        }
    }

    /// Adds the exercises to the workout, each with default sets. When `asSuperset` is true and there are
    /// at least two, they are grouped into one superset in the given order.
    private func addExercises(_ exercises: [Exercise], asSuperset: Bool) {
        precondition(self.workout.isCurrentWorkout == true)
        var added: [WorkoutExercise] = []
        for exercise in exercises {
            let workoutExercise = WorkoutExercise.create(context: self.managedObjectContext)
            self.workout.addToWorkoutExercises(workoutExercise)
            workoutExercise.exerciseUuid = exercise.uuid
            workoutExercise.addToWorkoutSets(self.createDefaultWorkoutSets(workoutExercise: workoutExercise))
            added.append(workoutExercise)
        }
        if asSuperset {
            self.workout.makeSuperset(from: added)
        }
        self.managedObjectContext.saveOrCrash()
    }
    
    private func createDefaultWorkoutSets(workoutExercise: WorkoutExercise) -> NSOrderedSet {
        var numberOfSets = 3
        // try to guess the number of sets
        if let history = try? managedObjectContext.fetch(workoutExercise.historyFetchRequest), history.count >= 3 {
            // one month since last workout and at least three workouts
            if let firstHistoryStart = history[0].workout?.start, let thirdHistoryStart = history[2].workout?.start {
                let cutoff = min(thirdHistoryStart, Calendar.current.date(byAdding: .month, value: -1, to: firstHistoryStart)!)
                let filteredAndSortedHistory = history
                    .filter {
                        guard let start = $0.workout?.start else { return false }
                        return start >= cutoff
                }
                .sorted {
                    ($0.workoutSets?.count ?? 0) < ($1.workoutSets?.count ?? 0)
                }
                
                assert(filteredAndSortedHistory.count >= 3)
                let median = filteredAndSortedHistory[filteredAndSortedHistory.count / 2]
                numberOfSets = median.workoutSets?.count ?? numberOfSets
            }
        }
        var workoutSets = [WorkoutSet]()
        for _ in 0..<numberOfSets {
            let workoutSet = WorkoutSet.create(context: managedObjectContext)
            workoutSets.append(workoutSet)
        }
        return NSOrderedSet(array: workoutSets)
    }

    private var workoutExercises: [WorkoutExercise] {
        workout.workoutExercises?.array as? [WorkoutExercise] ?? []
    }

    /// A reorder-list row: the exercise name, prefixed with its A / B / C badge when it is in a superset,
    /// so the grouping is visible while reordering.
    @ViewBuilder private func reorderRow(_ workoutExercise: WorkoutExercise) -> some View {
        let name = workoutExercise.exercise(in: exerciseStore.exercises)?.title ?? "Exercise"
        if let label = workoutExercise.supersetLabel {
            HStack(spacing: Theme.Spacing.s) {
                Text(label)
                    .font(.forgeCaption.weight(.bold))
                    .foregroundColor(.forgeSecondaryLabel)
                    .frame(width: 20, height: 20)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.forgeSeparator))
                Text(name)
            }
            .accessibilityLabel("Superset \(label), \(name)")
        } else {
            Text(name)
        }
    }
    
    @State private var workoutCommentInput: String? = nil
    private var workoutComment: Binding<String> {
        Binding(
            get: {
                self.workoutCommentInput ?? self.workout.comment ?? ""
        },
            set: { newValue in
                self.workoutCommentInput = newValue
        }
        )
    }
    private func adjustAndSaveWorkoutCommentInput() {
        guard let newValue = workoutCommentInput?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        workoutCommentInput = newValue
        workout.comment = newValue.isEmpty ? nil : newValue
        self.managedObjectContext.saveOrCrash()

    }
    
    @State private var workoutTitleInput: String? = nil
    private var workoutTitle: Binding<String> {
        Binding(
            get: {
                self.workoutTitleInput ?? self.workout.title ?? ""
            },
            set: { newValue in
                self.workoutTitleInput = newValue
            }
        )
    }
    private func adjustAndSaveWorkoutTitleInput() {
        guard let newValue = workoutTitleInput?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        workoutTitleInput = newValue
        workout.title = newValue.isEmpty ? nil : newValue
        self.managedObjectContext.saveOrCrash()
    }

    private var workoutCustomAttributes: Binding<[String: String]> {
        Binding(
            get: { self.workout.customAttributes },
            set: { newValue in
                self.workout.customAttributes = newValue
                self.managedObjectContext.saveOrCrash()
            }
        )
    }


    /// The finish button routes here: block an empty workout, otherwise confirm before finishing.
    private func requestFinish() {
        Haptics.impact(.medium)
        if workout.hasCompletedSets == true {
            showingFinishConfirmation = true
        } else {
            showingCannotFinish = true
        }
    }

    /// Message shown in the finish confirmation. Warns when unfinished sets will be dropped.
    private var finishConfirmationMessage: String {
        if workout.isCompleted == false {
            return "Sets you haven't completed will be removed. This can't be undone."
        }
        return "This ends and saves your workout."
    }

    /// Confirmed finish. If the workout came from a routine and its exercises or sets no longer match,
    /// ask whether to update the routine before finishing. Otherwise finish straight away.
    private func confirmFinish() {
        if let routine = workout.workoutRoutine, routine.differs(fromWorkout: workout) {
            // Defer so the finish alert has dismissed before the update alert presents.
            DispatchQueue.main.async { self.routineUpdatePending = routine }
        } else {
            finishWorkout(updateRoutine: false)
        }
    }

    private func finishWorkout(updateRoutine: Bool) {
        workout.finishOrCrash()

        // Sync after finishing, so the routine matches the cleaned-up structure (uncompleted sets gone).
        if updateRoutine, let routine = workout.workoutRoutine {
            routine.update(fromWorkout: workout)
            managedObjectContext.saveOrCrash()
        }

        // A success cue that the workout was saved.
        Haptics.success()
        AudioServicesPlaySystemSound(1103) // Tink sound

        // Land back on the dashboard. Native tab selection does not animate on its own.
        sceneState.selectedTab = .feed
    }

    private func cancelWorkout() {
        // Discarding is destructive, so a warning haptic rather than a success one.
        Haptics.warning()
        workout.cancelOrCrash()
    }
    
    private var cancelButton: some View {
        Button("Cancel") {
            if (self.workout.workoutExercises?.count ?? 0) == 0 {
                // the workout is empty, no need to confirm
                self.cancelWorkout()
            } else {
                self.showingCancelActionSheet = true
            }
        }
    }

    // Edit collapses the exercises to a reorderable list of names; Done returns to the inline cards.
    private var reorderButton: some View {
        Button(editMode == .active ? "Done" : "Edit") {
            Haptics.selection()
            if editMode == .active {
                // Commit the name and comment before the fields are torn down, so a name typed in edit
                // mode is saved even if the field never lost focus on its own.
                adjustAndSaveWorkoutTitleInput()
                adjustAndSaveWorkoutCommentInput()
            }
            withAnimation { editMode = editMode == .active ? .inactive : .active }
        }
    }

    // "Finish" sits in the top-right next to Edit, the common workout-app layout, so it is reachable
    // without scrolling to the end. The finish confirmation catches an accidental tap.
    private var finishButton: some View {
        Button("Finish") {
            self.requestFinish()
        }
        .fontWeight(.semibold)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // A prominent title header, matching the Workout tab's greeting but a little smaller, so
                // the active workout reads consistently with the rest of that tab.
                HStack {
                    Text(workout.displayTitle(in: exerciseStore.exercises, showPlan: settingsStore.showPlanInWorkoutTitle))
                        .font(.system(.title, design: .default).weight(.semibold))
                        .foregroundColor(.forgeLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.s)
                .padding(.bottom, Theme.Spacing.xs)

                // The timer row sits directly under the title as one header group; a single rule separates
                // it from the list below, so there is no boxed-in colored band.
                TimerBannerView(workout: workout, isEditing: editMode == .active)
                Divider()
                List {
                    // Characteristics. Edit mode always exposes the name and comment. Otherwise a blank
                    // workout shows a single empty name field, editable directly for quick naming, while
                    // a workout that already has a name (its own, or a routine's) shows only the comment
                    // it has; name, comment, and attributes are edited through Edit. Added content still
                    // appears read-only when present.
                    let hasName = !(workout.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || workout.workoutPlanAndRoutineTitle() != nil
                    let readComment = (workout.comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if editMode == .active {
                        Section(header: Text("Characteristics")) {
                            ClearableTextField(titleKey: "Name", text: workoutTitle, onCommit: { self.adjustAndSaveWorkoutTitleInput() })
                            ClearableTextField(titleKey: "Comment", text: workoutComment, onCommit: { self.adjustAndSaveWorkoutCommentInput() })
                        }
                    } else if !hasName || !readComment.isEmpty {
                        // A blank workout keeps its quick, directly editable name field. A comment shows
                        // read-only whenever it exists, even on a blank workout, so it never disappears
                        // after being entered. The name field and the comment can appear together.
                        Section(header: Text("Characteristics")) {
                            if !hasName {
                                ClearableTextField(titleKey: "Name", text: workoutTitle, onCommit: { self.adjustAndSaveWorkoutTitleInput() })
                            }
                            if !readComment.isEmpty {
                                Text(readComment).foregroundColor(.forgeSecondaryLabel)
                                    .editModeHint()
                            }
                        }
                    }
                    // The value of an attribute already present can be filled in directly (like naming a
                    // blank workout), so routine-seeded fields (location, mood) are quick to set. Adding a
                    // new attribute still goes through Edit.
                    CustomAttributesEditor(attributes: workoutCustomAttributes, isEditable: editMode == .active, valuesEditable: true)
                    // In edit mode the exercises collapse to a plain, reorderable list of names (drag to
                    // reorder, swipe/– to remove). Otherwise each exercise is a full card with its set
                    // table inline, so logging never leaves this screen.
                    if editMode == .active {
                        Section(header: Text("Reorder exercises".uppercased())) {
                            ForEach(workoutExercises) { workoutExercise in
                                reorderRow(workoutExercise)
                                    // The lifted drag preview has rounded corners; without an explicit row
                                    // background the corners reveal the black window behind the list.
                                    .listRowBackground(Color.forgeSurface)
                            }
                            .onMove { source, destination in
                                var exercises = self.workoutExercises
                                exercises.move(fromOffsets: source, toOffset: destination)
                                self.workout.workoutExercises = NSOrderedSet(array: exercises)
                                // A move can pull an exercise out of a superset or split one; restore the
                                // invariant so a stored group is always a contiguous run of two or more.
                                self.workout.normalizeSupersets()
                                self.managedObjectContext.saveOrCrash()
                            }
                            .onDelete { offsets in
                                let exercises = self.workoutExercises
                                for i in offsets {
                                    self.managedObjectContext.delete(exercises[i])
                                    exercises[i].workout?.removeFromWorkoutExercises(exercises[i])
                                }
                                // Clear any superset left with a single member after the removal.
                                self.workout.normalizeSupersets()
                                self.managedObjectContext.saveOrCrash()
                            }
                        }
                    } else {
                        // The first card carries the "Exercises" section header, so it renders in the
                        // same grouped style as the Characteristics and Attributes headers. A superset
                        // renders as one card holding its members; everything else is a single card.
                        ForEach(Array(workout.exerciseSlots.enumerated()), id: \.element.id) { index, slot in
                            switch slot {
                            case .single(let workoutExercise):
                                WorkoutExerciseDetailView(workoutExercise: workoutExercise, embedded: true, sectionHeader: index == 0 ? "Exercises" : nil)
                            case .superset(_, let exercises):
                                SupersetCard(exercises: exercises, sectionHeader: index == 0 ? "Exercises" : nil)
                            }
                        }
                    }

                    Section {
                        Button(action: {
                            self.activeSheet = .exerciseSelector
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add exercise")
                            }
                        }
                    }
                }
                .listStyleCompat_InsetGroupedListStyle()
                .environment(\.editMode, $editMode)
                .keyboardDoneToolbar()
            }
            .background(Color.forgeBackground.ignoresSafeArea())
            .navigationBarTitle(Text(""), displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { cancelButton }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    reorderButton
                    finishButton
                }
            }
        }
        .sheet(item: $activeSheet) { type in
            self.sheetView(type: type)
        }
        .alert("Discard workout?", isPresented: $showingCancelActionSheet) {
            Button("Discard", role: .destructive) { self.cancelWorkout() }
            Button("Keep going", role: .cancel) { }
        } message: {
            Text("This cannot be undone.")
        }
        .alert("Finish workout?", isPresented: $showingFinishConfirmation) {
            Button("Finish") { self.confirmFinish() }
                .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(finishConfirmationMessage)
        }
        .alert("Update routine?", isPresented: Binding(get: { routineUpdatePending != nil }, set: { if !$0 { routineUpdatePending = nil } })) {
            Button("Update") { self.finishWorkout(updateRoutine: true) }
                .keyboardShortcut(.defaultAction)
            Button("Keep routine", role: .cancel) { self.finishWorkout(updateRoutine: false) }
        } message: {
            Text("This workout's exercises or sets changed. Update the routine to match, or keep it as it was?")
        }
        .alert("No completed sets", isPresented: $showingCannotFinish) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Complete at least one set before finishing this workout.")
        }
    }
}

/// One card holding the members of a superset. It owns the section and the shared header (the superset
/// label and the rest note); each member renders its own rows and an A / B / C badge.
private struct SupersetCard: View {
    @Environment(\.managedObjectContext) private var managedObjectContext
    let exercises: [WorkoutExercise]
    let sectionHeader: String?

    @State private var showingNoteEditor = false

    /// The group's shared note, read from any member (they are kept equal).
    private var note: String? { exercises.first?.supersetNote }

    var body: some View {
        Section {
            supersetHeader
            ForEach(Array(exercises.enumerated()), id: \.element.objectID) { index, exercise in
                WorkoutExerciseDetailView(
                    workoutExercise: exercise,
                    embedded: true,
                    supersetMember: .init(
                        label: exercise.supersetLabel ?? "",
                        isFirst: index == 0,
                        isLast: index == exercises.count - 1
                    )
                )
            }
        } header: {
            if let sectionHeader { Text(sectionHeader) }
        }
    }

    /// A quiet leading label that marks the group, styled like the "Exercises" section header so it reads
    /// as part of the same system. Ungrouping lives in the trailing menu, on the group rather than in an
    /// exercise's menu.
    private var supersetHeader: some View {
        // An "S" chip (same style as the A/B/C member badges) marks the group; the note sits beside it.
        HStack(alignment: .center, spacing: Theme.Spacing.s) {
            Text("S")
                .font(.forgeCaption.weight(.bold))
                .foregroundColor(.forgeSecondaryLabel)
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.forgeSeparator))
                .accessibilityLabel("Superset")
            if let note {
                Text(note)
                    .font(.forgeCaption.italic())
                    .foregroundColor(.forgeSecondaryLabel)
                    .lineLimit(2)
            }
            Spacer()
            Menu {
                Button { showingNoteEditor = true } label: {
                    Label(note == nil ? "Add note" : "Change note", systemImage: "square.and.pencil")
                }
                Button(role: .destructive) { ungroup() } label: {
                    Label("Ungroup", systemImage: "link")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.forgeSecondaryLabel)
                    .frame(width: 34, height: 24)
                    .contentShape(Rectangle())
            }
        }
        .listRowInsets(EdgeInsets(top: Theme.Spacing.m, leading: Theme.Spacing.m, bottom: Theme.Spacing.s, trailing: Theme.Spacing.m))
        .sheet(isPresented: $showingNoteEditor) {
            if let anchor = exercises.first {
                NavigationStack {
                    SupersetNoteEditor(anchor: anchor)
                        .navigationBarTitle("Superset note", displayMode: .inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showingNoteEditor = false }.fontWeight(.semibold)
                            }
                        }
                }
            }
        }
    }

    private func ungroup() {
        guard let workout = exercises.first?.workout, let uuid = exercises.first?.supersetUUID else { return }
        Haptics.selection()
        workout.ungroupSuperset(id: uuid)
        managedObjectContext.saveOrCrash()
    }
}

/// Edits the note shared by a whole superset. Editing an anchor member writes the note to every member of
/// the group, so it survives reordering within the group.
private struct SupersetNoteEditor: View {
    @ObservedObject var anchor: WorkoutExercise
    @State private var draft = ""

    var body: some View {
        Form {
            Section(footer: Text("A note for the whole superset.")) {
                TextField("Note", text: $draft, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
        .onAppear { draft = anchor.supersetNote ?? "" }
        .onDisappear {
            anchor.setSupersetNote(draft)
            anchor.managedObjectContext?.saveOrCrash()
        }
    }
}

#if DEBUG
struct WorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        if RestTimerStore.shared.restTimerRemainingTime == nil {
            RestTimerStore.shared.restTimerStart = Date()
            RestTimerStore.shared.restTimerDuration = 10
        }
        return CurrentWorkoutView(workout: MockWorkoutData.metricRandom.currentWorkout)
            .mockEnvironment(weightUnit: .metric)
    }
}
#endif
