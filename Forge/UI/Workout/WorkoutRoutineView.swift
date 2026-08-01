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
    @State private var noteEditorExercise: WorkoutRoutineExercise?
    
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

    private func routineSets(_ ex: WorkoutRoutineExercise) -> [WorkoutRoutineSet] {
        ex.workoutRoutineSets?.array as? [WorkoutRoutineSet] ?? []
    }

    private func indexedRoutineSets(_ ex: WorkoutRoutineExercise) -> [(Int, WorkoutRoutineSet)] {
        routineSets(ex).enumerated().map { ($0 + 1, $1) }
    }

    private func addRoutineSet(to ex: WorkoutRoutineExercise) {
        let set = WorkoutRoutineSet.create(context: managedObjectContext)
        set.workoutRoutineExercise = ex
        managedObjectContext.saveOrCrash()
    }

    private func deleteRoutineSets(_ ex: WorkoutRoutineExercise, _ offsets: IndexSet) {
        let sets = routineSets(ex)
        for i in offsets {
            let set = sets[i]
            managedObjectContext.delete(set)
            set.workoutRoutineExercise?.removeFromWorkoutRoutineSets(set)
        }
        managedObjectContext.saveOrCrash()
    }

    /// One exercise as a card in view mode: a tappable name row (opens the full exercise editor for its
    /// comment, rep-target style, bodyweight mode, and superset note) with its set table inline below.
    @ViewBuilder private func exerciseCard(_ ex: WorkoutRoutineExercise) -> some View {
        Section {
            NavigationLink(destination: WorkoutRoutineExerciseView(workoutRoutineExercise: ex)) {
                HStack(spacing: Theme.Spacing.s) {
                    if let label = ex.supersetLabel {
                        Text(label)
                            .font(.forgeCaption.weight(.bold))
                            .foregroundColor(.forgeSecondaryLabel)
                            .frame(width: 20, height: 20)
                            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.forgeSeparator))
                            .accessibilityLabel("Superset \(label)")
                    }
                    Text(ex.exercise(in: exerciseStore.exercises)?.title ?? "Unknown Exercise")
                        .font(.forgeHeadline)
                }
            }
            ForEach(indexedRoutineSets(ex), id: \.1.id) { (index, set) in
                RoutineSetRow(workoutRoutineSet: set, index: index, singleTarget: ex.singleRepTargetValue, isEditable: true)
            }
            .onDelete { deleteRoutineSets(ex, $0) }
            Button { addRoutineSet(to: ex) } label: {
                HStack { Image(systemName: "plus"); Text("Add set") }
            }
        }
    }

    private var exerciseSelectorSheet: some View {
        AddExercisesSheet(
            exercises: exerciseStore.shownExercises,
            recentExercises: AddExercisesSheet.loadRecentExercises(context: managedObjectContext, exercises: exerciseStore.shownExercises),
            onAdd: { selection in self.addExercises(Array(selection), asSuperset: false) },
            onAddSuperset: { ordered in self.addExercises(ordered, asSuperset: true) }
        )
    }

    /// Adds the exercises to the routine. When `asSuperset` is true and there are at least two, they are
    /// grouped into one superset in the given order.
    private func addExercises(_ exercises: [Exercise], asSuperset: Bool) {
        var added: [WorkoutRoutineExercise] = []
        for exercise in exercises {
            let workoutRoutineExercise = WorkoutRoutineExercise.create(context: self.managedObjectContext)
            workoutRoutineExercise.workoutRoutine = self.workoutRoutine
            workoutRoutineExercise.exerciseUuid = exercise.uuid
            added.append(workoutRoutineExercise)
        }
        if asSuperset {
            self.workoutRoutine.makeSuperset(from: added)
        }
        self.managedObjectContext.saveOrCrash()
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
                        .editModeHint()
                    if let comment = workoutRoutine.comment, !comment.isEmpty {
                        LabeledContent("Comment") { Text(comment).foregroundColor(.secondary) }
                            .editModeHint()
                    }
                }
            }

            CustomAttributesEditor(attributes: routineCustomAttributes, isEditable: editMode?.wrappedValue.isEditing == true)

            // Edit mode uses the compact list for reordering, deleting, and superset notes. View mode shows
            // each exercise as a card with its set table inline, like the live workout.
            if editMode?.wrappedValue.isEditing == true {
            Section(header: Text("Exercises")) {
                ForEach(workoutRoutineExercises) { workoutRoutineExercise in
                    NavigationLink(destination: WorkoutRoutineExerciseView(workoutRoutineExercise: workoutRoutineExercise)) {
                        HStack(spacing: Theme.Spacing.s) {
                            if let label = workoutRoutineExercise.supersetLabel {
                                Text(label)
                                    .font(.forgeCaption.weight(.bold))
                                    .foregroundColor(.forgeSecondaryLabel)
                                    .frame(width: 20, height: 20)
                                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.forgeSeparator))
                                    .accessibilityLabel("Superset \(label)")
                            }
                            VStack(alignment: .leading) {
                                Text(workoutRoutineExercise.exercise(in: self.exerciseStore.exercises)?.title ?? "Unknown Exercise")
                                workoutRoutineExercise.subtitle.map {
                                    Text($0)
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                // Show the group's shared note once, under the first member.
                                if workoutRoutineExercise.supersetIndex == 0, let note = workoutRoutineExercise.supersetNote {
                                    Text(note)
                                        .font(.forgeCaption.italic())
                                        .foregroundColor(.forgeSecondaryLabel)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                    // Note and Ungroup live on the row, not in a per-exercise menu. Swipe from the leading
                    // edge; the exercises stay in the routine.
                    .swipeActions(edge: .leading) {
                        if let uuid = workoutRoutineExercise.supersetUUID {
                            Button { noteEditorExercise = workoutRoutineExercise } label: {
                                Label(workoutRoutineExercise.supersetNote == nil ? "Add note" : "Change note", systemImage: "square.and.pencil")
                            }
                            .tint(.forgeAccent)
                            Button {
                                self.workoutRoutine.ungroupSuperset(id: uuid)
                                self.managedObjectContext.saveOrCrash()
                            } label: {
                                Label("Ungroup", systemImage: "link")
                            }
                            .tint(.forgeSecondaryLabel)
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
                    // Clear any superset left with a single member after the removal.
                    self.workoutRoutine.normalizeSupersets()
                    self.managedObjectContext.saveOrCrash()
                }
                .onMove { source, destination in
                    var workoutRoutineExercises = self.workoutRoutineExercises
                    workoutRoutineExercises.move(fromOffsets: source, toOffset: destination)
                    self.workoutRoutine.workoutRoutineExercises = NSOrderedSet(array: workoutRoutineExercises)
                    // A move can split a superset; restore the contiguous-group invariant.
                    self.workoutRoutine.normalizeSupersets()
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
            } else {
                ForEach(workoutRoutineExercises) { exerciseCard($0) }
                Section {
                    Button(action: { self.showExerciseSelector = true }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add exercises")
                        }
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
        .sheet(item: $noteEditorExercise) { exercise in
            NavigationStack {
                RoutineSupersetNoteEditor(anchor: exercise)
                    .navigationBarTitle("Superset note", displayMode: .inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { noteEditorExercise = nil }.fontWeight(.semibold)
                        }
                    }
            }
            .presentationDetents([.medium])
        }
    }
}

/// Edits a routine superset's shared note, writing it to every member of the group.
private struct RoutineSupersetNoteEditor: View {
    @ObservedObject var anchor: WorkoutRoutineExercise
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
struct WorkoutRoutineView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WorkoutRoutineView(workoutRoutine: MockWorkoutData.metric.workoutRoutine)
                .mockEnvironment(weightUnit: .metric)
        }
    }
}
#endif
