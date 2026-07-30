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
                onAdd: { selection in
                    for exercise in selection {
                        let workoutExercise = WorkoutExercise.create(context: self.managedObjectContext)
                        self.workout.addToWorkoutExercises(workoutExercise)
                        workoutExercise.exerciseUuid = exercise.uuid
                        precondition(self.workout.isCurrentWorkout == true)
                        workoutExercise.addToWorkoutSets(self.createDefaultWorkoutSets(workoutExercise: workoutExercise))
                    }
                    self.managedObjectContext.saveOrCrash()
                }
            ).typeErased
        }
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
                                Text(workoutExercise.exercise(in: exerciseStore.exercises)?.title ?? "Exercise")
                                    // The lifted drag preview has rounded corners; without an explicit row
                                    // background the corners reveal the black window behind the list.
                                    .listRowBackground(Color.forgeSurface)
                            }
                            .onMove { source, destination in
                                var exercises = self.workoutExercises
                                exercises.move(fromOffsets: source, toOffset: destination)
                                self.workout.workoutExercises = NSOrderedSet(array: exercises)
                                self.managedObjectContext.saveOrCrash()
                            }
                            .onDelete { offsets in
                                let exercises = self.workoutExercises
                                for i in offsets {
                                    self.managedObjectContext.delete(exercises[i])
                                    exercises[i].workout?.removeFromWorkoutExercises(exercises[i])
                                }
                                self.managedObjectContext.saveOrCrash()
                            }
                        }
                    } else {
                        // The first card carries the "Exercises" section header, so it renders in the
                        // same grouped style as the Characteristics and Attributes headers.
                        ForEach(Array(workoutExercises.enumerated()), id: \.element.objectID) { index, workoutExercise in
                            WorkoutExerciseDetailView(workoutExercise: workoutExercise, embedded: true, sectionHeader: index == 0 ? "Exercises" : nil)
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
