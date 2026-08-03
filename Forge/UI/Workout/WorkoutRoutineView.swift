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
    // The set-options sheet is presented once here, not per row (per-row presenters wedged UIKit).
    @State private var optionsSet: WorkoutRoutineSet?
    @State private var exerciseSheet: ExerciseSheet?

    /// The exercise-level sheet reached from a card's "..." menu. One presenter, keyed by kind and exercise.
    private enum ExerciseSheet: Identifiable {
        case note(WorkoutRoutineExercise)
        case info(WorkoutRoutineExercise)
        case history(WorkoutRoutineExercise)
        var id: String {
            switch self {
            case .note(let e): return "note-\(e.objectID)"
            case .info(let e): return "info-\(e.objectID)"
            case .history(let e): return "history-\(e.objectID)"
            }
        }
    }
    
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

    /// One exercise as a card in view mode: the name, a "..." menu with the rep-target and bodyweight
    /// controls and the exercise actions (info, note, previous sessions, remove), and its set table. Nothing
    /// navigates to open the exercise as its own screen; everything is edited here.
    @ViewBuilder private func exerciseCard(_ ex: WorkoutRoutineExercise) -> some View {
        Section {
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
                Spacer()
                exerciseMenu(ex)
            }
            ForEach(indexedRoutineSets(ex), id: \.1.id) { (index, set) in
                RoutineSetRow(workoutRoutineSet: set, index: index, singleTarget: ex.singleRepTargetValue, isEditable: true, onOpenOptions: { optionsSet = set })
            }
            .onDelete { deleteRoutineSets(ex, $0) }
            Button { addRoutineSet(to: ex) } label: {
                HStack { Image(systemName: "plus"); Text("Add set") }
            }
        }
    }

    private func exerciseMenu(_ ex: WorkoutRoutineExercise) -> some View {
        Menu {
            Menu {
                Picker("Rep target", selection: Binding(
                    get: { ex.singleRepTargetValue },
                    set: { ex.singleRepTargetValue = $0; managedObjectContext.saveOrCrash() }
                )) {
                    Text("Rep range").tag(false)
                    Text("Single rep target").tag(true)
                }
            } label: {
                Label("Rep target", systemImage: "number")
            }
            if ex.exercise(in: exerciseStore.exercises)?.isBodyweight == true {
                Menu {
                    Picker("Weight", selection: Binding(
                        get: { ex.assistedValue },
                        set: { ex.assistedValue = $0; managedObjectContext.saveOrCrash() }
                    )) {
                        Text("Added weight").tag(false)
                        Text("Assisted").tag(true)
                    }
                } label: {
                    Label("Weight", systemImage: "scalemass")
                }
            }
            Divider()
            Button { exerciseSheet = .note(ex) } label: { Label("Note", systemImage: "square.and.pencil") }
            Button { exerciseSheet = .info(ex) } label: { Label("Exercise info", systemImage: "info.circle") }
            Button { exerciseSheet = .history(ex) } label: { Label("Previous sessions", systemImage: "clock.arrow.circlepath") }
            Divider()
            Button(role: .destructive) { removeExercise(ex) } label: { Label("Remove exercise", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundColor(.forgeSecondaryLabel)
                .frame(width: 44, height: 30)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Exercise options")
    }

    private func removeExercise(_ ex: WorkoutRoutineExercise) {
        managedObjectContext.delete(ex)
        ex.workoutRoutine?.removeFromWorkoutRoutineExercises(ex)
        workoutRoutine.normalizeSupersets()
        managedObjectContext.saveOrCrash()
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
                    // A plain row (no navigation): edit mode is only for reordering, deleting, and the
                    // superset note/ungroup swipe. The exercise is never opened as its own screen.
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
        .sheet(item: $optionsSet) { RoutineSetOptionsView(workoutRoutineSet: $0) }
        .sheet(item: $exerciseSheet) { sheet in
            switch sheet {
            case .note(let ex):
                RoutineExerciseNoteEditor(workoutRoutineExercise: ex)
            case .info(let ex):
                if let exercise = ex.exercise(in: exerciseStore.exercises) {
                    NavigationStack { ExerciseDetailView(exercise: exercise) }
                }
            case .history(let ex):
                if let exercise = ex.exercise(in: exerciseStore.exercises) {
                    NavigationStack {
                        ExerciseHistoryView(exercise: exercise)
                            .navigationBarTitle("Previous sessions", displayMode: .inline)
                    }
                }
            }
        }
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

/// An inline routine-set row. A single-target exercise shows one reps field; a range shows min and max.
/// Values commit when a field resigns focus, matching value entry in the live workout.
private struct RoutineSetRow: View {
    @ObservedObject var workoutRoutineSet: WorkoutRoutineSet
    let index: Int
    let singleTarget: Bool
    let isEditable: Bool
    /// Opens this set's type and note from the routine-level sheet presenter.
    var onOpenOptions: () -> Void = {}

    @State private var minInput = ""
    @State private var maxInput = ""

    private func syncFromModel() {
        minInput = workoutRoutineSet.minRepetitionsValue.map { "\($0)" } ?? ""
        maxInput = workoutRoutineSet.maxRepetitionsValue.map { "\($0)" } ?? ""
    }

    private func commitMin() {
        let value = Int16(minInput.trimmingCharacters(in: .whitespaces))
        workoutRoutineSet.minRepetitionsValue = value
        if singleTarget {
            workoutRoutineSet.maxRepetitionsValue = value
            maxInput = value.map { "\($0)" } ?? ""
        }
        workoutRoutineSet.managedObjectContext?.saveOrCrash()
    }

    private func commitMax() {
        workoutRoutineSet.maxRepetitionsValue = Int16(maxInput.trimmingCharacters(in: .whitespaces))
        workoutRoutineSet.managedObjectContext?.saveOrCrash()
    }

    private var readText: String {
        WorkoutRoutineSetCell.repetitionIntervalString(
            minRepetitions: workoutRoutineSet.minRepetitionsValue.map(Int.init),
            maxRepetitions: workoutRoutineSet.maxRepetitionsValue.map(Int.init)
        ) ?? "—"
    }

    private func field(_ text: Binding<String>, placeholder: String, onCommit: @escaping () -> Void) -> some View {
        RightAlignedNumberField(text: text, placeholder: placeholder, keyboardType: .numberPad, alignment: .center, onCommit: onCommit)
            .forgeSetValueBox(width: 56)
    }

    private var hasNote: Bool { !(workoutRoutineSet.comment ?? "").isEmpty }

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Button(action: onOpenOptions) {
                ForgeSetNumberChip(
                    index: index,
                    tint: workoutRoutineSet.tagValue?.color,
                    showsNote: hasNote
                )
            }
            .buttonStyle(.plain)
            Spacer()
            if isEditable {
                if singleTarget {
                    field($minInput, placeholder: "reps", onCommit: commitMin)
                } else {
                    field($minInput, placeholder: "min", onCommit: commitMin)
                    Text("–").foregroundColor(.forgeSecondaryLabel)
                    field($maxInput, placeholder: "max", onCommit: commitMax)
                }
            } else {
                Text(readText).font(.forgeValue).foregroundColor(.forgeSecondaryLabel)
            }
            Text("reps").font(.forgeCaption).foregroundColor(.forgeSecondaryLabel)
        }
        .onAppear { syncFromModel() }
        .onChange(of: singleTarget) { _, _ in syncFromModel() }
    }
}

/// The type and note editor for a routine set. Rep targets remain editable inline in `RoutineSetRow`.
private struct RoutineSetOptionsView: View {
    @ObservedObject var workoutRoutineSet: WorkoutRoutineSet
    @Environment(\.dismiss) private var dismiss
    @State private var noteInput = ""

    private func saveNote() {
        let trimmed = noteInput.trimmingCharacters(in: .whitespacesAndNewlines)
        workoutRoutineSet.comment = trimmed.isEmpty ? nil : trimmed
        workoutRoutineSet.managedObjectContext?.saveOrCrash()
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Set type")) {
                    ForEach(WorkoutSetTag.allCases, id: \.self) { tag in
                        Button {
                            workoutRoutineSet.tagValue = workoutRoutineSet.tagValue == tag ? nil : tag
                            workoutRoutineSet.managedObjectContext?.saveOrCrash()
                        } label: {
                            HStack {
                                Image(systemName: "circle.fill").imageScale(.small).foregroundColor(tag.color)
                                Text(tag.title.capitalized).foregroundColor(.primary)
                                Spacer()
                                if workoutRoutineSet.tagValue == tag {
                                    Image(systemName: "checkmark").foregroundColor(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section(header: Text("Note")) {
                    ClearableTextField(titleKey: "Note", text: $noteInput, onCommit: saveNote)
                }
            }
            .navigationBarTitle("Set", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") { saveNote(); dismiss() })
            .onAppear { noteInput = workoutRoutineSet.comment ?? "" }
        }
        .presentationDetents([.medium])
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

/// A note for a specific routine exercise (not a set), opened from the card's "..." menu.
private struct RoutineExerciseNoteEditor: View {
    @ObservedObject var workoutRoutineExercise: WorkoutRoutineExercise
    @Environment(\.managedObjectContext) private var managedObjectContext
    @Environment(\.dismiss) private var dismiss
    @State private var noteInput = ""

    private func save() {
        let trimmed = noteInput.trimmingCharacters(in: .whitespacesAndNewlines)
        workoutRoutineExercise.comment = trimmed.isEmpty ? nil : trimmed
        managedObjectContext.saveOrCrash()
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Note")) {
                    ClearableTextField(titleKey: "Note", text: $noteInput, onCommit: save)
                }
            }
            .navigationBarTitle("Note", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") { save(); dismiss() }.fontWeight(.semibold))
            .onAppear { noteInput = workoutRoutineExercise.comment ?? "" }
        }
        .presentationDetents([.medium])
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
