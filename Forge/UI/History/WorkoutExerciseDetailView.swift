//
//  WorkoutExerciseDetailView.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 23.06.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import CoreData
import AVKit
import WorkoutDataKit

struct WorkoutExerciseDetailView : View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @Environment(\.editMode) var editMode
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var restTimerStore: RestTimerStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    
    @FetchRequest(fetchRequest: WorkoutExercise.fetchRequest()) var workoutExerciseHistory // will be overwritten in init()
    @ObservedObject var workoutExercise: WorkoutExercise

    @State private var moreSheetSet: WorkoutSet? = nil
    
    @State private var showExerciseInfo = false
    
    @State private var workoutExerciseCommentInput: String? = nil
    private var workoutExerciseComment: Binding<String> {
        Binding(
            get: {
                return self.workoutExerciseCommentInput ?? self.workoutExercise.comment ?? ""
            },
            set: { newValue in
                self.workoutExerciseCommentInput = newValue
            }
        )
    }
    private func adjustAndSaveWorkoutExerciseCommentInput() {
        guard let newValue = workoutExerciseCommentInput?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        workoutExerciseCommentInput = newValue
        workoutExercise.comment = newValue.isEmpty ? nil : newValue
        self.managedObjectContext.saveOrCrash()
    }
    
    init(workoutExercise: WorkoutExercise) {
        self.workoutExercise = workoutExercise
        _workoutExerciseHistory = FetchRequest(fetchRequest: workoutExercise.historyFetchRequest)
    }

    private func workoutSets(for workoutExercise: WorkoutExercise) -> [WorkoutSet] {
        workoutExercise.workoutSets?.array as? [WorkoutSet] ?? []
    }
    
    private func indexedWorkoutSets(for workoutExercise: WorkoutExercise) -> [(Int, WorkoutSet)] {
        workoutSets(for: workoutExercise).enumerated().map { ($0 + 1, $1) }
    }
    
    private var isCurrentWorkout: Bool {
        workoutExercise.workout?.isCurrentWorkout ?? false
    }

    private var firstUncompletedSet: WorkoutSet? {
        workoutExercise.workoutSets?.first(where: { !($0 as! WorkoutSet).isCompleted }) as? WorkoutSet
    }
    
    /// Pre-fill the values of uncompleted sets from the previous session so the user just edits
    /// or confirms them inline (mirrors what the old editor did on selection).
    private func prefillPlaceholders() {
        for case let set as WorkoutSet in (workoutExercise.workoutSets?.array ?? []) where !set.isCompleted {
            if set.repetitions == nil || set.weight == nil {
                initRepsAndWeight(for: set)
            }
        }
    }

    private func toggleComplete(_ set: WorkoutSet) {
        if set.isCompleted {
            set.isCompleted = false
            Haptics.selection()
            managedObjectContext.saveOrCrash()
        } else {
            completeSet(set)
        }
    }

    private func completeSet(_ set: WorkoutSet) {
        guard isCurrentWorkout else { return }
        guard set.weightValue >= 0, set.repetitionsValue >= 0 else { return }
        set.isCompleted = true
        let workout = set.workoutExercise?.workout
        workout?.start = workout?.start ?? Date()
        moveWorkoutExerciseBehindLastBegun()
        Haptics.success()
        AudioServicesPlaySystemSound(1103) // Tink sound
        restTimerStore.restTimerDuration = restTimerDuration
        restTimerStore.restTimerStart = Date() // start the rest timer
        managedObjectContext.saveOrCrash()
    }
    
    private func initRepsAndWeight(for set: WorkoutSet) {
        let index = workoutExercise.workoutSets!.index(of: set)
        let previousSet: WorkoutSet?
        if index > 0 { // not the first set
            if let set = previousSetFromEqualExercise(for: set, at: index) {
                previousSet = set
            } else {
                previousSet = workoutExercise.workoutSets![index - 1] as? WorkoutSet
            }
        } else { // first set
            previousSet = workoutExerciseHistory.first?.workoutSets?.firstObject as? WorkoutSet
        }
        if let previousSet = previousSet {
            set.repetitionsValue = previousSet.repetitionsValue
            if let target = previousSet.targetWeightValue {
                // A target planned last time carries forward: pre-fill the weight from it and keep
                // the target on this set so the row can mark it as planned.
                set.weightValue = target
                set.targetWeightValue = target
            } else {
                set.weightValue = previousSet.weightValue
            }
        } else {
            // TODO: let the user configure default repetitions and weight
            set.repetitionsValue = 5
            if workoutExercise.exercise(in: exerciseStore.exercises)?.type == .barbell {
                let weightUnit = self.settingsStore.weightUnit
                set.weightValue = WeightUnit.convert(weight: weightUnit.barbellWeight, from: weightUnit, to: .metric)
            }
        }
    }
    
    // looks for a previous exercise where the same sequence of sets was performed
    private func previousSetFromEqualExercise(for set: WorkoutSet, at index: Int) -> WorkoutSet? {
        let exercise = workoutExerciseHistory.first {
            guard let count = $0.workoutSets?.count, index < count  else { return false }
            for i in 0..<index {
                guard let workoutSet1 = workoutExercise.workoutSets?[i] as? WorkoutSet else { return false }
                guard let workoutSet2 = $0.workoutSets?[i] as? WorkoutSet else { return false }
                if workoutSet1.weightValue != workoutSet2.weightValue || workoutSet1.repetitionsValue != workoutSet2.repetitionsValue {
                    return false
                }
            }
            return true
        }
        return exercise?.workoutSets?[index] as? WorkoutSet
    }


    private func moveWorkoutExerciseBehindLastBegun() {
        assert(isCurrentWorkout)
        guard let workout = workoutExercise.workout else { return }
        
        workout.removeFromWorkoutExercises(workoutExercise) // remove before doing the other stuff!
        
        let lastBegun = workout.workoutExercises?
            .compactMap { $0 as? WorkoutExercise }
            .last { $0.numberOfCompletedSets ?? 0 > 0 }
        
        if let lastBegun = lastBegun, let index = workout.workoutExercises?.index(of: lastBegun), index != NSNotFound {
            workout.insertIntoWorkoutExercises(workoutExercise, at: index + 1) // insert after last begun exercise
        } else {
            workout.insertIntoWorkoutExercises(workoutExercise, at: 0) // no workout exercise begun
        }
    }
    
    private func rpe(rpe: Double) -> some View {
        VStack {
            Group {
                Text(String(format: "%.1f", rpe))
                Text("RPE")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
    
    private var currentWorkoutSets: some View {
        ForEach(indexedWorkoutSets(for: workoutExercise), id: \.1.id) { (index, workoutSet) in
            ActiveSetRow(
                workoutSet: workoutSet,
                index: index,
                weightUnit: settingsStore.weightUnit,
                isCurrentWorkout: isCurrentWorkout,
                isUpNext: firstUncompletedSet == workoutSet,
                showRPE: settingsStore.showRPE,
                onToggleComplete: { toggleComplete(workoutSet) },
                onMore: { moreSheetSet = workoutSet }
            )
        }
        .onDelete { offsets in
            let workoutSets = self.workoutSets(for: self.workoutExercise)
            for i in offsets {
                let workoutSet = workoutSets[i]
                self.managedObjectContext.delete(workoutSet)
                workoutSet.workoutExercise?.removeFromWorkoutSets(workoutSet)
            }
            DispatchQueue.main.async { // iOS 14 beta crashes if this is not async
                self.managedObjectContext.saveOrCrash()
            }
        }
        // TODO: move is yet too buggy
        //                        .onMove { source, destination in
        //                            guard source.first != destination || source.count > 1 else { return }
        //                            // make sure the destination is completed
        //                            guard (self.workoutExercise.workoutSets![destination] as! WorkoutSet).isCompleted else { return }
        //                            // make sure all sources are completed
        //                            guard source.reduce(true, { (allCompleted, index) in
        //                                allCompleted && (self.workoutExercise.workoutSets![index] as! WorkoutSet).isCompleted
        //                            }) else { return }
        //
        //                            // TODO: replace with swift 5.1 move() function when available
        //                            guard let index = source.first else { return }
        //                            guard let workoutSet = self.workoutExercise.workoutSets?[index] as? WorkoutSet else { return }
        //                            self.workoutExercise.removeFromWorkoutSets(at: index)
        //                            self.workoutExercise.insertIntoWorkoutSets(workoutSet, at: destination)
        //                        }
    }
    
    private var addSetButton: some View {
        Button(action: {
            Haptics.impact(.light)
            let workoutSet = WorkoutSet.create(context: self.workoutExercise.managedObjectContext!)
            workoutSet.workoutExercise = self.workoutExercise
            if !self.isCurrentWorkout {
                // don't allow uncompleted sets if not in current workout
                workoutSet.isCompleted = true
            }
            self.prefillPlaceholders() // pre-fill the new set from the previous session
            self.managedObjectContext.saveOrCrash()
        }) {
            HStack {
                Image(systemName: "plus")
                Text("Add Set")
            }
        }
    }
    
    private var historyWorkoutSets: some View {
        ForEach(workoutExerciseHistory) { pastWorkoutExercise in
            Section {
                // Tap the date to open that session's version of this exercise (notes and sets),
                // pushed within the current tab.
                NavigationLink {
                    WorkoutExerciseDetailView(workoutExercise: pastWorkoutExercise)
                } label: {
                    WorkoutExerciseSectionHeader(workoutExercise: pastWorkoutExercise)
                }

                pastWorkoutExercise.comment.map {
                    Text($0.enquoted)
                        .lineLimit(1)
                        .font(Font.body.italic())
                        .foregroundColor(.secondary)
                }
                ForEach(self.indexedWorkoutSets(for: pastWorkoutExercise), id: \.1.id) { (index, workoutSet) in
                    WorkoutSetCell(workoutSet: workoutSet, index: index, colorMode: .disabled)
                }
            }
        }
    }
    
    private var restTimerDuration: TimeInterval {
        if let uuid = workoutExercise.exerciseUuid, let time = exerciseStore.restTime(forExercise: uuid) {
            return time
        }
        return settingsStore.defaultRestTime
    }
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    TextField("Comment", text: workoutExerciseComment, onEditingChanged: { isEditingTextField in
                        if !isEditingTextField {
                            self.adjustAndSaveWorkoutExerciseCommentInput()
                        }
                    })

                    currentWorkoutSets
                    addSetButton
                }
                
                historyWorkoutSets
            }
            .listStyleCompat_InsetGroupedListStyle()

            if let exercise = workoutExercise.exercise(in: exerciseStore.exercises) {
                NavigationLink(destination: ExerciseDetailView(exercise: exercise).environmentObject(self.settingsStore), isActive: $showExerciseInfo) { EmptyView() }
            }
        }
        .sheet(item: $moreSheetSet) { set in
            NavigationStack {
                SetMoreView(workoutSet: set, weightUnit: settingsStore.weightUnit, showRPE: settingsStore.showRPE)
                    .navigationBarTitle(Text(set.displayTitle(weightUnit: settingsStore.weightUnit)), displayMode: .inline)
                    .navigationBarItems(trailing: Button("Done") { moreSheetSet = nil })
            }
        }
        .navigationBarTitle(Text(workoutExercise.exercise(in: exerciseStore.exercises)?.title ?? ""), displayMode: .inline)
        .navigationBarItems(trailing:
            HStack(spacing: NAVIGATION_BAR_SPACING) {
                if workoutExercise.exercise(in: exerciseStore.exercises) != nil {
                    // Use Button because NavigationLink in navigation bar works unreliable (iOS 14)
                    Button(action: {
                        showExerciseInfo = true
                    }, label: {
                        Image(systemName: "info.circle")
                            .padding([.leading, .top, .bottom])
                    })
                }
                EditButton()
            }
        )
        .onAppear {
            self.prefillPlaceholders()
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

/// A single set row with inline-editable weight and reps, a "more" button (tag / comment / RPE /
/// targets), and a checkmark to complete the set. Replaces the old bottom editor panel.
private struct ActiveSetRow: View {
    @ObservedObject var workoutSet: WorkoutSet
    let index: Int
    let weightUnit: WeightUnit
    let isCurrentWorkout: Bool
    let isUpNext: Bool
    let showRPE: Bool
    var onToggleComplete: () -> Void
    var onMore: () -> Void

    @FocusState private var focus: Field?
    private enum Field { case weight, reps }

    private var weightField: Binding<Double> {
        Binding(
            get: { WeightUnit.convert(weight: workoutSet.weightValue, from: .metric, to: weightUnit) },
            set: { workoutSet.weightValue = max(0, min(WeightUnit.convert(weight: $0, from: weightUnit, to: .metric), WorkoutSet.MAX_WEIGHT)) }
        )
    }

    private var repsField: Binding<Double> {
        Binding(
            get: { Double(workoutSet.repetitionsValue) },
            set: { workoutSet.repetitionsValue = Int16(max(0, min($0, Double(WorkoutSet.MAX_REPETITIONS)))) }
        )
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Text("\(index)")
                .font(.forgeCaption)
                .foregroundColor(.forgeSecondaryLabel)
                .frame(minWidth: 16, alignment: .leading)

            TextField("0", value: weightField, format: .number)
                .keyboardType(.decimalPad)
                .focused($focus, equals: .weight)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 76)
                .font(.forgeValue)
            Text(weightUnit.unit.symbol)
                .font(.forgeCaption)
                .foregroundColor(.forgeSecondaryLabel)

            // Marks a value pre-filled from a target planned last session.
            if !workoutSet.isCompleted, workoutSet.targetWeightValue != nil {
                Image(systemName: "target")
                    .font(.caption2)
                    .foregroundColor(.forgeSecondaryLabel)
                    .accessibilityLabel("Planned target")
            }

            Text("×").foregroundColor(.forgeSecondaryLabel)

            TextField("0", value: repsField, format: .number)
                .keyboardType(.numberPad)
                .focused($focus, equals: .reps)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 44)
                .font(.forgeValue)
            Text("reps")
                .font(.forgeCaption)
                .foregroundColor(.forgeSecondaryLabel)

            Spacer(minLength: Theme.Spacing.s)

            if showRPE, let rpe = workoutSet.rpeValue {
                Text(String(format: "%.1f", rpe))
                    .font(.forgeCaption)
                    .foregroundColor(.forgeSecondaryLabel)
            }

            Menu {
                ForEach(WorkoutSetTag.allCases, id: \.self) { tag in
                    Button {
                        workoutSet.tagValue = (workoutSet.tagValue == tag) ? nil : tag
                        workoutSet.managedObjectContext?.saveOrCrash()
                    } label: {
                        Label(tag.title.capitalized, systemImage: workoutSet.tagValue == tag ? "checkmark" : "circle")
                    }
                }
            } label: {
                Image(systemName: "tag")
                    .foregroundColor(workoutSet.tagValue?.color ?? .forgeSecondaryLabel)
                    .frame(width: 30, height: 40)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Set tag")

            Button(action: onMore) {
                Image(systemName: "ellipsis")
                    .foregroundColor(.forgeSecondaryLabel)
                    .frame(width: 30, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More options")

            if isCurrentWorkout {
                Button(action: onToggleComplete) {
                    Image(systemName: workoutSet.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 27))
                        .foregroundColor(workoutSet.isCompleted ? .forgeSuccess : (isUpNext ? .forgeLabel : .forgeSecondaryLabel))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(workoutSet.isCompleted ? "Set completed" : "Complete set")
            }
        }
        .foregroundColor(workoutSet.isCompleted ? .forgeLabel : .forgeSecondaryLabel)
    }
}

#if DEBUG
struct WorkoutExerciseDetailView_Previews : PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WorkoutExerciseDetailView(workoutExercise: MockWorkoutData.metricRandom.workoutExercise)
                .mockEnvironment(weightUnit: .metric)
        }
    }
}
#endif
