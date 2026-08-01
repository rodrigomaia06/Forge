//
//  WorkoutRoutineExerciseView.swift
//  Iron
//
//  Created by Karim Abou Zeid on 21.03.20.
//  Copyright © 2020 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import WorkoutDataKit

struct WorkoutRoutineExerciseView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @Environment(\.editMode) var editMode
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    
    @ObservedObject var workoutRoutineExercise: WorkoutRoutineExercise

    @State private var workoutRoutineExerciseCommentInput: String? = nil
    private var workoutRoutineExerciseComment: Binding<String> {
        Binding(
            get: {
                self.workoutRoutineExerciseCommentInput ?? self.workoutRoutineExercise.comment ?? ""
            },
            set: { newValue in
                self.workoutRoutineExerciseCommentInput = newValue
            }
        )
    }
    private func adjustAndSaveWorkoutRoutineExerciseCommentInput() {
        guard let newValue = workoutRoutineExerciseCommentInput?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        workoutRoutineExerciseCommentInput = newValue
        workoutRoutineExercise.comment = newValue.isEmpty ? nil : newValue
        self.managedObjectContext.saveOrCrash()
    }
    
    private func workoutRoutineSets(for workoutRoutineExercise: WorkoutRoutineExercise) -> [WorkoutRoutineSet] {
        workoutRoutineExercise.workoutRoutineSets?.array as? [WorkoutRoutineSet] ?? []
    }
    
    private func indexedWorkoutRoutineSets(for workoutRoutineExercise: WorkoutRoutineExercise) -> [(Int, WorkoutRoutineSet)] {
        workoutRoutineSets(for: workoutRoutineExercise).enumerated().map { ($0 + 1, $1) }
    }
    
    
    private var workoutRoutineSets: some View {
        ForEach(indexedWorkoutRoutineSets(for: workoutRoutineExercise), id: \.1.id) { (index, workoutRoutineSet) in
            RoutineSetRow(
                workoutRoutineSet: workoutRoutineSet,
                index: index,
                singleTarget: settingsStore.routineSingleRepTarget,
                isEditable: editMode?.wrappedValue != .active
            )
        }
        .onDelete { offsets in
            let workoutRoutineSets = self.workoutRoutineSets(for: self.workoutRoutineExercise)
            for i in offsets {
                let workoutRoutineSet = workoutRoutineSets[i]
                self.managedObjectContext.delete(workoutRoutineSet)
                workoutRoutineSet.workoutRoutineExercise?.removeFromWorkoutRoutineSets(workoutRoutineSet)
            }
            self.managedObjectContext.saveOrCrash()
        }
        .onMove { source, destination in
            var workoutRoutineSets = self.workoutRoutineSets(for: self.workoutRoutineExercise)
            workoutRoutineSets.move(fromOffsets: source, toOffset: destination)
            self.workoutRoutineExercise.workoutRoutineSets = NSOrderedSet(array: workoutRoutineSets)
            self.managedObjectContext.saveOrCrash()
        }
    }
    
    private var addSetButton: some View {
        Button(action: {
            // New sets start with no rep target, so the range is entered deliberately rather than
            // defaulting to a number the user has to clear.
            let workoutRoutineSet = WorkoutRoutineSet.create(context: self.managedObjectContext)
            workoutRoutineSet.workoutRoutineExercise = self.workoutRoutineExercise
            self.managedObjectContext.saveOrCrash()
        }) {
            HStack {
                Image(systemName: "plus")
                Text("Add set")
            }
        }
    }
    
    private var isBodyweight: Bool {
        workoutRoutineExercise.exercise(in: exerciseStore.exercises)?.isBodyweight ?? false
    }

    private var bodyweightModeSection: some View {
        Section(footer: Text("A workout started from this routine logs added or assisted weight accordingly, without asking each time.")) {
            Picker("Weight kind", selection: Binding(
                get: { workoutRoutineExercise.assistedValue },
                set: { workoutRoutineExercise.assistedValue = $0; managedObjectContext.saveOrCrash() }
            )) {
                Text("Added").tag(false)
                Text("Assisted").tag(true)
            }
            .pickerStyle(.segmented)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                if isBodyweight { bodyweightModeSection }
                Section {
                    ClearableTextField(titleKey: "Comment", text: workoutRoutineExerciseComment, onCommit: { self.adjustAndSaveWorkoutRoutineExerciseCommentInput() })

                    workoutRoutineSets
                    addSetButton
                }
            }
            .listStyleCompat_InsetGroupedListStyle()
            .keyboardDoneToolbar()
        }
        .navigationBarTitle(Text(workoutRoutineExercise.exercise(in: exerciseStore.exercises)?.title ?? ""), displayMode: .inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                iOS13_3.map { // otherwise crashes when going back on iOS 13.2.2
                    workoutRoutineExercise.exercise(in: exerciseStore.exercises).map {
                        NavigationLink(destination: ExerciseDetailView(exercise: $0)) {
                                Image(systemName: "info.circle")
                        }
                    }
                }
                EditButton()
            }
        }
        .onDisappear {
            self.managedObjectContext.saveOrCrash()
        }
    }
    
    // kind of a hack
    private var iOS13_3: Void? {
        if #available(iOS 13.3, *) {
            return ()
        } else {
            return nil
        }
    }
}

/// An inline, editable routine set row: the set number and its rep target, entered in place like the live
/// workout instead of a pushed dragger editor. A single-target style shows one reps field (min = max); a
/// range style shows min and max. Values commit when a field resigns focus, not per keystroke.
private struct RoutineSetRow: View {
    @ObservedObject var workoutRoutineSet: WorkoutRoutineSet
    let index: Int
    let singleTarget: Bool
    let isEditable: Bool

    @State private var minInput = ""
    @State private var maxInput = ""

    private static let boxHeight: CGFloat = 36

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
            .frame(width: 56, height: Self.boxHeight)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(.tertiarySystemFill)))
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Text("\(index)")
                .font(.forgeCaption)
                .foregroundColor(.forgeSecondaryLabel)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.forgeSecondaryLabel.opacity(0.14)))
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
    }
}

#if DEBUG
struct WorkoutRoutineExerciseView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutRoutineExerciseView(workoutRoutineExercise: MockWorkoutData.metric.workoutRoutineExercise)
            .mockEnvironment(weightUnit: .metric)
    }
}
#endif
