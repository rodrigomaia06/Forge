//
//  WorkoutRoutineView.swift
//  Iron
//
//  Created by Karim Abou Zeid on 21.03.20.
//  Copyright © 2020 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import WorkoutDataKit

struct WorkoutRoutineView: View {
    @EnvironmentObject var exerciseStore: ExerciseStore
    @Environment(\.managedObjectContext) var managedObjectContext
    
    @ObservedObject var workoutRoutine: WorkoutRoutine

    @Environment(\.editMode) var editMode

    @State private var showExerciseSelector = false
    
    @State private var workoutRoutineTitleInput: String? = nil
    private var workoutRoutineTitle: Binding<String> {
        Binding(
            get: {
                self.workoutRoutineTitleInput ?? self.workoutRoutine.title ?? ""
            },
            set: { newValue in
                self.workoutRoutineTitleInput = newValue
            }
        )
    }
    private func adjustAndSaveWorkoutRoutineTitleInput() {
        guard let newValue = workoutRoutineTitleInput?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        workoutRoutineTitleInput = newValue
        workoutRoutine.title = newValue.isEmpty ? nil : newValue
        self.managedObjectContext.saveOrCrash()
    }
    
    @State private var workoutRoutineCommentInput: String? = nil
    private var workoutRoutineComment: Binding<String> {
        Binding(
            get: {
                self.workoutRoutineCommentInput ?? self.workoutRoutine.comment ?? ""
            },
            set: { newValue in
                self.workoutRoutineCommentInput = newValue
            }
        )
    }

    private var routineCustomAttributes: Binding<[String: String]> {
        Binding(
            get: { self.workoutRoutine.customAttributes },
            set: { newValue in
                self.workoutRoutine.customAttributes = newValue
                self.managedObjectContext.saveOrCrash()
            }
        )
    }
    private func adjustAndSaveWorkoutRoutineCommentInput() {
        guard let newValue = workoutRoutineCommentInput?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        workoutRoutineCommentInput = newValue
        workoutRoutine.comment = newValue.isEmpty ? nil : newValue
        self.managedObjectContext.saveOrCrash()
    }
    
    private var workoutRoutineExercises: [WorkoutRoutineExercise] {
        workoutRoutine.workoutRoutineExercises?.array as? [WorkoutRoutineExercise] ?? []
    }
    
    private var exerciseSelectorSheet: some View {
        AddExercisesSheet(
            exercises: exerciseStore.shownExercises,
            recentExercises: AddExercisesSheet.loadRecentExercises(context: managedObjectContext, exercises: exerciseStore.shownExercises),
            onAdd: { selection in
                for exercise in selection {
                    let workoutRoutineExercise = WorkoutRoutineExercise.create(context: self.managedObjectContext)
                    workoutRoutineExercise.workoutRoutine = self.workoutRoutine
                    workoutRoutineExercise.exerciseUuid = exercise.uuid
                    // TODO: add default sets?
                }
                self.managedObjectContext.saveOrCrash()
            }
        )
    }
    
    var body: some View {
        List {
            // Characteristics: the fields all show when viewing, but are editable only after Edit, so a
            // stray tap can't change the routine.
            Section(header: Text("Characteristics")) {
                if editMode?.wrappedValue.isEditing == true {
                    ClearableTextField(titleKey: "Title", text: workoutRoutineTitle, onCommit: { self.adjustAndSaveWorkoutRoutineTitleInput() })
                    ClearableTextField(titleKey: "Comment", text: workoutRoutineComment, onCommit: { self.adjustAndSaveWorkoutRoutineCommentInput() })
                } else {
                    LabeledContent("Title") { Text(workoutRoutine.title ?? "Untitled").foregroundColor(.secondary) }
                    if let comment = workoutRoutine.comment, !comment.isEmpty {
                        LabeledContent("Comment") { Text(comment).foregroundColor(.secondary) }
                    }
                }
            }

            CustomAttributesEditor(attributes: routineCustomAttributes, isEditable: editMode?.wrappedValue.isEditing == true)

            Section(header: Text("Exercises")) {
                ForEach(workoutRoutineExercises) { workoutRoutineExercise in
                    NavigationLink(destination: WorkoutRoutineExerciseView(workoutRoutineExercise: workoutRoutineExercise)) {
                        VStack(alignment: .leading) {
                            Text(workoutRoutineExercise.exercise(in: self.exerciseStore.exercises)?.title ?? "Unknown Exercise")
                            workoutRoutineExercise.subtitle.map {
                                Text($0)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    let workoutRoutineExercises = self.workoutRoutineExercises
                    for i in offsets {
                        let workoutRoutineExercise = workoutRoutineExercises[i]
                        self.managedObjectContext.delete(workoutRoutineExercise)
                        workoutRoutineExercise.workoutRoutine?.removeFromWorkoutRoutineExercises(workoutRoutineExercise)
                    }
                    self.managedObjectContext.saveOrCrash()
                }
                .onMove { source, destination in
                    var workoutRoutineExercises = self.workoutRoutineExercises
                    workoutRoutineExercises.move(fromOffsets: source, toOffset: destination)
                    self.workoutRoutine.workoutRoutineExercises = NSOrderedSet(array: workoutRoutineExercises)
                    self.managedObjectContext.saveOrCrash()
                }
                // Reordering only in edit mode, so a stray long-press can't change the routine's order.
                .moveDisabled(editMode?.wrappedValue.isEditing != true)

                Button(action: {
                    self.showExerciseSelector = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add exercises")
                    }
                }
            }
        }
        .listStyleCompat_InsetGroupedListStyle()
        .keyboardDoneToolbar()
        // Commit the title and comment when Edit is turned off, so tapping Done saves even if the field
        // never lost focus (the text field's own onEditingChanged does not fire when it is removed).
        .onChange(of: editMode?.wrappedValue.isEditing) { isEditing in
            if isEditing == false {
                adjustAndSaveWorkoutRoutineTitleInput()
                adjustAndSaveWorkoutRoutineCommentInput()
            }
        }
        .navigationBarTitle(Text(workoutRoutine.displayTitle), displayMode: .inline)
        .navigationBarItems(trailing: EditButton())
        .sheet(isPresented: self.$showExerciseSelector) {
            self.exerciseSelectorSheet
        }
    }
}

#if DEBUG
struct WorkoutRoutineView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WorkoutRoutineView(workoutRoutine: MockWorkoutData.metric.workoutRoutine)
                .mockEnvironment(weightUnit: .metric)
        }
    }
}
#endif
