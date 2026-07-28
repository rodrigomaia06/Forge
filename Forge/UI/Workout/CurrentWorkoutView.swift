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
    }
    
    private func currentWorkoutExerciseDetailView(workoutExercise: WorkoutExercise) -> some View {
        VStack(spacing: 0) {
            // on the iPad we have two columns at once so we already have a TimerBannerView
            if UIDevice.current.userInterfaceIdiom != .pad {
                if #available(iOS 15.0, *) {
                    Divider()
                }
                TimerBannerView(workout: workout)
                Divider()
            }
            WorkoutExerciseDetailView(workoutExercise: workoutExercise)
                .layoutPriority(1)
                .environmentObject(settingsStore)
        }
    }

    private func workoutExerciseCell(workoutExercise: WorkoutExercise) -> some View {
        let totalSets = workoutExercise.workoutSets?.count ?? 0
        let completedSets = workoutExercise.numberOfCompletedSets ?? 0
        let isCompleted = workoutExercise.isCompleted ?? false

        return NavigationLink(destination: currentWorkoutExerciseDetailView(workoutExercise: workoutExercise)) {
            HStack(spacing: Theme.Spacing.m) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(workoutExercise.exercise(in: exerciseStore.exercises)?.title ?? "Unknown Exercise")
                        .font(.forgeHeadline)
                        .foregroundColor(isCompleted ? .forgeSecondaryLabel : .forgeLabel)
                    if totalSets > 0 {
                        Text("\(completedSets) of \(totalSets) sets")
                            .font(.forgeCaption)
                            .foregroundColor(.forgeSecondaryLabel)
                    }
                }
                .layoutPriority(1)
                Spacer(minLength: Theme.Spacing.s)
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.forgeSuccess)
                }
            }
            .padding(.vertical, Theme.Spacing.xxs)
        }
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
        workout.cancelOrCrash()
        
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()
        feedbackGenerator.notificationOccurred(.success)
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if #available(iOS 15.0, *) {
                    Divider()
                }
                TimerBannerView(workout: workout)
                Divider()
                List {
                    Section {
                        // TODO: add clear button
                        TextField("Title", text: workoutTitle, onEditingChanged: { isEditingTextField in
                            if !isEditingTextField {
                                self.adjustAndSaveWorkoutTitleInput()
                            }
                        })
                        TextField("Comment", text: workoutComment, onEditingChanged: { isEditingTextField in
                            if !isEditingTextField {
                                self.adjustAndSaveWorkoutCommentInput()
                            }
                        })
                    }
                    Section(header: Text("Exercises".uppercased())) {
                        ForEach(workoutExercises) { workoutExercise in
                            self.workoutExerciseCell(workoutExercise: workoutExercise)
                        }
                        .onDelete { offsets in
                            let workoutExercises = self.workoutExercises
                            for i in offsets {
                                let workoutExercise = workoutExercises[i]
                                self.managedObjectContext.delete(workoutExercise)
                                workoutExercise.workout?.removeFromWorkoutExercises(workoutExercise)
                            }
                        }
                        .onMove { source, destination in
                            var workoutExercises = self.workoutExercises
                            workoutExercises.move(fromOffsets: source, toOffset: destination)
                            self.workout.workoutExercises = NSOrderedSet(array: workoutExercises)
                        }
                        
                        Button(action: {
                            self.activeSheet = .exerciseSelector
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add Exercises")
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
            }
            .navigationBarTitle(Text(workout.displayTitle(in: exerciseStore.exercises)), displayMode: .inline)
            .navigationBarItems(leading: cancelButton, trailing: EditButton())
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
