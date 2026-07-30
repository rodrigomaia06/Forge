//
//  WorkoutRoutineView.swift
//  Iron
//
//  Created by Karim Abou Zeid on 21.03.20.
//  Copyright © 2020 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import CoreData
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
    
    /// The superset group header, matching the live workout: a link glyph, the shared note, and a menu
    /// with Add/Change note and Ungroup. Shown on the first member of a group.
    private func supersetGroupHeader(_ anchor: WorkoutRoutineExercise) -> some View {
        HStack(alignment: .center, spacing: Theme.Spacing.s) {
            Image(systemName: "link")
                .font(.body)
                .frame(height: 24)
                .foregroundColor(.forgeSecondaryLabel)
                .accessibilityLabel("Superset")
            if let note = anchor.supersetNote {
                Text(note)
                    .font(.forgeCaption.italic())
                    .foregroundColor(.forgeSecondaryLabel)
                    .lineLimit(2)
            }
            Spacer()
            Menu {
                Button { noteEditorExercise = anchor } label: {
                    Label(anchor.supersetNote == nil ? "Add note" : "Change note", systemImage: "square.and.pencil")
                }
                Button(role: .destructive) {
                    if let uuid = anchor.supersetUUID {
                        self.workoutRoutine.ungroupSuperset(id: uuid)
                        self.managedObjectContext.saveOrCrash()
                    }
                } label: {
                    Label("Ungroup", systemImage: "link")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.forgeSecondaryLabel)
                    .frame(width: 34, height: 24)
                    .contentShape(Rectangle())
            }
        }
    }

    /// The exercises grouped for display: a run of consecutive single exercises, or one superset.
    private enum RoutineSection: Identifiable {
        case singles([WorkoutRoutineExercise])
        case superset([WorkoutRoutineExercise])

        var exercises: [WorkoutRoutineExercise] {
            switch self {
            case .singles(let e), .superset(let e): return e
            }
        }
        var id: NSManagedObjectID { exercises[0].objectID }
    }

    private var routineSections: [RoutineSection] {
        var result: [RoutineSection] = []
        for slot in workoutRoutine.exerciseSlots {
            switch slot {
            case .single(let exercise):
                if case .singles(var arr)? = result.last {
                    arr.append(exercise)
                    result[result.count - 1] = .singles(arr)
                } else {
                    result.append(.singles([exercise]))
                }
            case .superset(_, let members):
                result.append(.superset(members))
            }
        }
        return result
    }

    private func routineExerciseRow(_ exercise: WorkoutRoutineExercise, showBadge: Bool) -> some View {
        NavigationLink(destination: WorkoutRoutineExerciseView(workoutRoutineExercise: exercise)) {
            HStack(spacing: Theme.Spacing.s) {
                if showBadge, let label = exercise.supersetLabel {
                    Text(label)
                        .font(.forgeCaption.weight(.bold))
                        .foregroundColor(.forgeSecondaryLabel)
                        .frame(width: 20, height: 20)
                        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.forgeSeparator))
                        .accessibilityLabel("Superset \(label)")
                }
                VStack(alignment: .leading) {
                    Text(exercise.exercise(in: self.exerciseStore.exercises)?.title ?? "Unknown Exercise")
                    exercise.subtitle.map {
                        Text($0).foregroundColor(.secondary).font(.caption)
                    }
                }
            }
        }
    }

    /// The flat edit-mode row: the name, prefixed with the A / B / C badge when grouped.
    private func routineReorderRow(_ exercise: WorkoutRoutineExercise) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            if let label = exercise.supersetLabel {
                Text(label)
                    .font(.forgeCaption.weight(.bold))
                    .foregroundColor(.forgeSecondaryLabel)
                    .frame(width: 20, height: 20)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.forgeSeparator))
            }
            Text(exercise.exercise(in: self.exerciseStore.exercises)?.title ?? "Unknown Exercise")
        }
    }

    private func deleteExercises(at offsets: IndexSet, in exercises: [WorkoutRoutineExercise]) {
        for i in offsets {
            let exercise = exercises[i]
            self.managedObjectContext.delete(exercise)
            exercise.workoutRoutine?.removeFromWorkoutRoutineExercises(exercise)
        }
        // Clear any superset left with a single member after the removal.
        self.workoutRoutine.normalizeSupersets()
        self.managedObjectContext.saveOrCrash()
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

            if editMode?.wrappedValue.isEditing == true {
                // Edit: one flat, reorderable list of names; the badge shows the grouping.
                Section(header: Text("Exercises")) {
                    ForEach(workoutRoutineExercises) { exercise in
                        routineReorderRow(exercise)
                    }
                    .onDelete { offsets in deleteExercises(at: offsets, in: workoutRoutineExercises) }
                    .onMove { source, destination in
                        var exercises = self.workoutRoutineExercises
                        exercises.move(fromOffsets: source, toOffset: destination)
                        self.workoutRoutine.workoutRoutineExercises = NSOrderedSet(array: exercises)
                        // A move can split a superset; restore the contiguous-group invariant.
                        self.workoutRoutine.normalizeSupersets()
                        self.managedObjectContext.saveOrCrash()
                    }
                }
            } else {
                // Non-edit: each superset is its own card so its start and end are clear; a run of single
                // exercises shares a card.
                ForEach(Array(routineSections.enumerated()), id: \.element.id) { index, section in
                    Section(header: index == 0 ? Text("Exercises") : nil) {
                        switch section {
                        case .singles(let exercises):
                            ForEach(exercises) { routineExerciseRow($0, showBadge: false) }
                                .onDelete { offsets in deleteExercises(at: offsets, in: exercises) }
                        case .superset(let members):
                            supersetGroupHeader(members[0])
                            ForEach(members) { routineExerciseRow($0, showBadge: true) }
                        }
                    }
                }
            }

            Section {
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
