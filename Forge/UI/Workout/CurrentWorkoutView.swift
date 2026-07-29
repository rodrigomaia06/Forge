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

    private func finishWorkout() {
        workout.finishOrCrash()

        // haptic feedback
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()
        feedbackGenerator.notificationOccurred(.success)
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
            withAnimation { editMode = editMode == .active ? .inactive : .active }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if #available(iOS 15.0, *) {
                    Divider()
                }
                TimerBannerView(workout: workout)
                Divider()
                List {
                    // Characteristics. A workout with no name yet (a blank workout) shows the name and
                    // comment fields directly, so it can be named without entering edit mode. A workout
                    // that already has a name (its own, or a routine's) hides the box; the name and
                    // comment stay editable through Edit, so a stray tap mid-workout can't change them.
                    let hasName = !(workout.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || workout.workoutPlanAndRoutineTitle() != nil
                    if !hasName || editMode == .active {
                        Section(header: Text("Characteristics")) {
                            ClearableTextField(titleKey: "Name", text: workoutTitle, onCommit: { self.adjustAndSaveWorkoutTitleInput() })
                            ClearableTextField(titleKey: "Comment", text: workoutComment, onCommit: { self.adjustAndSaveWorkoutCommentInput() })
                        }
                    } else if let comment = workout.comment, !comment.isEmpty {
                        Section(header: Text("Characteristics")) {
                            Text(comment).foregroundColor(.forgeSecondaryLabel)
                        }
                    }
                    // Custom fields like location or mood, seeded from the routine. Shown when present.
                    // Adding a new field needs edit mode, but the value of a field that is already there
                    // can be filled in directly, so routine-seeded fields don't require Edit.
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
                    Section {
                        Button("Finish workout") {
                            self.requestFinish()
                        }
                        .buttonStyle(ForgePrimaryButtonStyle())
                        // Inset from the card edges so the rounded button reads as a button, not a bar.
                        .listRowInsets(EdgeInsets(top: Theme.Spacing.s, leading: Theme.Spacing.m, bottom: Theme.Spacing.s, trailing: Theme.Spacing.m))
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyleCompat_InsetGroupedListStyle()
                .environment(\.editMode, $editMode)
                .keyboardDoneToolbar()
            }
            .navigationBarTitle(Text(workout.displayTitle(in: exerciseStore.exercises)), displayMode: .inline)
            .navigationBarItems(leading: cancelButton, trailing: reorderButton)
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
            Button("Finish") { self.finishWorkout() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(finishConfirmationMessage)
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
