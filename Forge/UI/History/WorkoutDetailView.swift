//
//  WorkoutDetailView.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 22.06.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import WorkoutDataKit
import os.log

struct WorkoutDetailView : View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var sceneState: SceneState
    @ObservedObject var workout: Workout

    // Owned here (not the ambient editMode) so the Edit/Done control can be a plain text button. The
    // system EditButton rendered a "Done" checkmark overlapping the "Edit" label inside the nav glass.
    @State private var editMode: EditMode = .inactive
    @State private var showingExerciseSelectorSheet = false

    @State private var activityItems: [Any]?

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

    private var workoutCustomAttributes: Binding<[String: String]> {
        Binding(
            get: { self.workout.customAttributes },
            set: { newValue in
                self.workout.customAttributes = newValue
                self.managedObjectContext.saveOrCrash()
            }
        )
    }
    private func adjustAndSaveWorkoutTitleInput() {
        guard let newValue = workoutTitleInput?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        workoutTitleInput = newValue
        workout.title = newValue.isEmpty ? nil : newValue
        self.managedObjectContext.saveOrCrash()
    }

    private var workoutExercises: [WorkoutExercise] {
        workout.workoutExercises?.array as? [WorkoutExercise] ?? []
    }
    
    private func workoutSets(workoutExercise: WorkoutExercise) -> [WorkoutSet] {
        workoutExercise.workoutSets?.array as? [WorkoutSet] ?? []
    }
    
    private func workoutExerciseView(workoutExercise: WorkoutExercise) -> some View {
        VStack(alignment: .leading) {
            Text(workoutExercise.exercise(in: self.exerciseStore.exercises)?.title ?? "")
                .font(.body)
            workoutExercise.comment.map {
                Text($0.enquoted)
                    .lineLimit(1)
                    .font(Font.caption.italic())
                    .foregroundColor(.secondary)
            }
            ForEach(self.workoutSets(workoutExercise: workoutExercise)) { workoutSet in
                Text(workoutSet.logTitle(weightUnit: self.settingsStore.weightUnit))
                    .font(Font.body.monospacedDigit())
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
        }
    }
    
    /// Share this workout as a routine (a template), so importing it adds a routine rather than
    /// injecting a past workout into someone's History.
    private func shareAsJSON() {
        do {
            let data = try WorkoutDataExchange.exportRoutine(fromWorkout: workout)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("routine.json")
            try data.write(to: url)
            self.activityItems = [url]
        } catch {
            os_log("Could not export workout as routine: %@", type: .error, error.localizedDescription)
        }
    }

    var body: some View {
        List {
            Section {
                WorkoutDetailBannerView(workout: workout)
                    .padding([.top, .bottom])
                    .frame(maxWidth: .infinity)
                    // A thin white rule under the summary, in place of the old muscle-group color.
                    .overlay(alignment: .bottom) {
                        Capsule()
                            .fill(Color.forgeLabel)
                            .frame(height: 3)
                            .padding(.horizontal, Theme.Spacing.m)
                    }
            }
            
            // Title and comment are editable only in edit mode, so browsing a finished workout cannot
            // change what was recorded. Read mode shows the comment when there is one.
            if editMode.isEditing {
                Section {
                    ClearableTextField(titleKey: "Title", text: workoutTitle, onCommit: { self.adjustAndSaveWorkoutTitleInput() })
                    ClearableTextField(titleKey: "Comment", text: workoutComment, onCommit: { self.adjustAndSaveWorkoutCommentInput() })
                }
            } else if let comment = workout.comment, !comment.isEmpty {
                Section {
                    Text(comment)
                }
            }
                
                Section {
                    // The start and end are editable only in edit mode, so a stray tap while browsing
                    // a finished workout cannot change its recorded times.
                    if editMode.isEditing {
                        DatePicker(selection: $workout.safeStart, in: ...min(workout.safeEnd, Date())) {
                            Text("Start")
                        }

                        DatePicker(selection: $workout.safeEnd, in: workout.safeStart...Date()) {
                            Text("End")
                        }
                    } else {
                        LabeledContent("Start") { Text(workout.safeStart.formatted(date: .abbreviated, time: .shortened)) }
                        LabeledContent("End") { Text(workout.safeEnd.formatted(date: .abbreviated, time: .shortened)) }
                    }
                }

                CustomAttributesEditor(attributes: workoutCustomAttributes, isEditable: editMode.isEditing)

            Section {
                ForEach(workoutExercises) { workoutExercise in
                    NavigationLink(destination: WorkoutExerciseDetailView(workoutExercise: workoutExercise).environmentObject(self.settingsStore)) {
                        self.workoutExerciseView(workoutExercise: workoutExercise)
                    }
                }
                .onDelete { offsets in
                    let workoutExercises = self.workoutExercises
                    for i in offsets {
                        let workoutExercise = workoutExercises[i]
                        self.managedObjectContext.delete(workoutExercise)
                        workoutExercise.workout?.removeFromWorkoutExercises(workoutExercise)
                    }
                    self.managedObjectContext.saveOrCrash()
                }
                .onMove { source, destination in
                    guard var workoutExercises = self.workout.workoutExercises?.array as? [WorkoutExercise] else { return }
                    workoutExercises.move(fromOffsets: source, toOffset: destination)
                    self.workout.workoutExercises = NSOrderedSet(array: workoutExercises)
                    self.managedObjectContext.saveOrCrash()
                }
                // Reordering only in edit mode, so a stray long-press drag can't change a past workout's
                // exercise order by accident.
                .moveDisabled(!editMode.isEditing)
                
                if editMode.isEditing {
                    Button(action: {
                        self.showingExerciseSelectorSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Exercises")
                        }
                    }
                }
            }
        }
        .listStyleCompat_InsetGroupedListStyle()
        .environment(\.editMode, $editMode)
        .keyboardDoneToolbar()
        // Commit the title and comment when Edit is turned off, so tapping Done saves even if the field
        // never lost focus (the text field's own onCommit does not fire when it is removed).
        .onChange(of: editMode.isEditing) { isEditing in
            if !isEditing {
                adjustAndSaveWorkoutTitleInput()
                adjustAndSaveWorkoutCommentInput()
                // A clear success cue that the edits to this past workout were saved.
                Haptics.success()
            }
        }
        .navigationBarTitle(Text(workout.displayTitle(in: exerciseStore.exercises, showPlan: settingsStore.showPlanInWorkoutTitle)), displayMode: .inline)
        .navigationBarItems(trailing:
            HStack(spacing: NAVIGATION_BAR_SPACING) {
                // A Menu attached to the button, rather than an action sheet, so the options appear
                // reliably right under the control.
                Menu {
                    Button {
                        guard let logText = self.workout.logText(in: self.exerciseStore.exercises, weightUnit: self.settingsStore.weightUnit) else { return }
                        self.activityItems = [logText]
                    } label: {
                        Label("Share as text", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        self.shareAsJSON()
                    } label: {
                        Label("Share as routine", systemImage: "doc.badge.arrow.up")
                    }
                    Button {
                        Self.repeatWorkout(workout: self.workout, settingsStore: self.settingsStore, sceneState: sceneState)
                    } label: {
                        Label("Repeat", systemImage: "arrow.clockwise")
                    }
                    Button {
                        Self.repeatWorkoutBlank(workout: self.workout, settingsStore: self.settingsStore, sceneState: sceneState)
                    } label: {
                        Label("Repeat blank", systemImage: "arrow.clockwise.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .imageScale(.large)
                }
                // A plain text button, not the system EditButton, whose "Done" checkmark overlapped the
                // "Edit" label inside the nav glass group.
                Button(editMode.isEditing ? "Done" : "Edit") {
                    Haptics.selection()
                    withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                }
            }
        )
        .sheet(isPresented: $showingExerciseSelectorSheet) {
            AddExercisesSheet(
                exercises: self.exerciseStore.shownExercises,
                recentExercises: AddExercisesSheet.loadRecentExercises(context: self.managedObjectContext, exercises: self.exerciseStore.shownExercises),
                onAdd: { selection in
                    for exercise in selection {
                        let workoutExercise = WorkoutExercise.create(context: self.managedObjectContext)
                        self.workout.addToWorkoutExercises(workoutExercise)
                        workoutExercise.exerciseUuid = exercise.uuid
                    }
                    self.managedObjectContext.saveOrCrash()
            })
        }
        .overlay(ActivitySheet(activityItems: $activityItems))
    }
}

// MARK: Actions
extension WorkoutDetailView {
    static func repeatWorkout(workout: Workout, settingsStore: SettingsStore, sceneState: SceneState) {
        guard let newWorkout = workout.copyForRepeat(blank: false) else { return }
        
        guard let context = workout.managedObjectContext else { return }
        guard let count = try? context.count(for: Workout.currentWorkoutFetchRequest), count == 0 else {
            // Blocked: a workout is already in progress.
            Haptics.error()
            return
        }
        
        Haptics.impact(.medium)
        newWorkout.startOrCrash()

        sceneState.selectedTab = .workout
    }
    
    static func repeatWorkoutBlank(workout: Workout, settingsStore: SettingsStore, sceneState: SceneState) {
        guard let newWorkout = workout.copyForRepeat(blank: true) else { return }
        
        guard let context = workout.managedObjectContext else { return }
        guard let count = try? context.count(for: Workout.currentWorkoutFetchRequest), count == 0 else {
            // Blocked: a workout is already in progress.
            Haptics.error()
            return
        }
        
        Haptics.impact(.medium)
        newWorkout.startOrCrash()

        sceneState.selectedTab = .workout
    }
}

#if DEBUG
struct WorkoutDetailView_Previews : PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WorkoutDetailView(workout: MockWorkoutData.metricRandom.workout)
                .mockEnvironment(weightUnit: .metric)
        }
    }
}
#endif
