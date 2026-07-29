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
    @EnvironmentObject var sceneState: SceneState
    
    @FetchRequest(fetchRequest: WorkoutExercise.fetchRequest()) var workoutExerciseHistory // will be overwritten in init()
    @ObservedObject var workoutExercise: WorkoutExercise

    @State private var moreSheetSet: WorkoutSet? = nil
    @State private var showExerciseNote = false
    @State private var showHistory = false
    @State private var showAllHistory = false
    @State private var showWarmupCalculator = false

    /// Past sessions to show. Capped at the most recent few until the user asks for more.
    private var displayedHistory: [WorkoutExercise] {
        let all = Array(workoutExerciseHistory)
        return showAllHistory ? all : Array(all.prefix(3))
    }
    
    @State private var showExerciseInfo = false
    // History (standalone) starts read-only; its Edit button flips this so sets become editable.
    @State private var historyEditMode: EditMode = .inactive

    /// Sets are editable during the live workout, or in history only after tapping Edit.
    private var setsEditable: Bool { isCurrentWorkout || historyEditMode == .active }

    /// When true, renders as a card embedded in the current-workout list (name header + set table,
    /// no navigation bar). When false, renders as the pushed full-screen view used from history.
    let embedded: Bool
    /// Header for the embedded card's section. Set only on the first exercise so the group gets a
    /// single "Exercises" header in the same grouped style as the Characteristics and Attributes ones.
    private let sectionHeader: String?

    init(workoutExercise: WorkoutExercise, embedded: Bool = false, sectionHeader: String? = nil) {
        self.workoutExercise = workoutExercise
        self.embedded = embedded
        self.sectionHeader = sectionHeader
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
            // A target planned last time applies once: pre-fill the weight from it, but do not copy the
            // target onto this set, or it would propagate to every future session. After this, the
            // weight just carries forward normally like any logged value.
            if let target = previousSet.targetWeightValue {
                set.weightValue = target
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
    
    private var hasExerciseNote: Bool { !(workoutExercise.comment ?? "").isEmpty }

    // Only shown when there is a note. Adding a note is in the ... menu, so nothing is displayed by
    // default (an always-visible "Add a note" row read as off-center clutter).
    @ViewBuilder private var exerciseNoteSubtitle: some View {
        if hasExerciseNote {
            Button {
                showExerciseNote = true
            } label: {
                Text(workoutExercise.comment ?? "")
                    .font(.forgeCaption.italic())
                    .lineLimit(2)
                    .foregroundColor(.forgeSecondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Theme.Spacing.xs)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Exercise note: \(workoutExercise.comment ?? "")")
        }
    }

    /// Column headers above the set rows (Set, Previous, kg, Reps).
    private var setsHeader: some View {
        HStack(spacing: Theme.Spacing.s) {
            Text("Set").frame(width: 36)
            Text("Previous").frame(maxWidth: .infinity, alignment: .center)
            Text(settingsStore.weightUnit.unit.symbol).frame(width: 68)
            Text("Reps").frame(width: 60)
            if isCurrentWorkout { Color.clear.frame(width: 34, height: 0) }
        }
        .font(.forgeCaption)
        .foregroundColor(.forgeSecondaryLabel)
        // Tight against the header above and the first set below.
        .listRowInsets(EdgeInsets(top: 2, leading: Theme.Spacing.m, bottom: 2, trailing: Theme.Spacing.m))
    }

    /// The matching set from the most recent previous session, formatted (e.g. "42.5 kg × 4").
    private func previousPerformance(atZeroBased index: Int) -> String? {
        guard index >= 0,
              let sets = workoutExerciseHistory.first?.workoutSets?.array as? [WorkoutSet],
              index < sets.count else { return nil }
        return sets[index].displayTitle(weightUnit: settingsStore.weightUnit)
    }

    private func deleteSet(_ workoutSet: WorkoutSet) {
        managedObjectContext.delete(workoutSet)
        workoutSet.workoutExercise?.removeFromWorkoutSets(workoutSet)
        DispatchQueue.main.async { // iOS 14 beta crashes if this is not async
            self.managedObjectContext.saveOrCrash()
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
                previousText: previousPerformance(atZeroBased: index - 1),
                isEditable: setsEditable,
                onToggleComplete: { toggleComplete(workoutSet) },
                onMore: { moreSheetSet = workoutSet }
            )
            // Explicit red tint: the app-wide white tint was overriding the destructive colour, so the
            // swipe button rendered white on the dark background instead of a full red delete action.
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    deleteSet(workoutSet)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(Color.forgeDestructive)
            }
        }
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
            // New sets start empty; the previous session is shown as a reference, not pre-filled.
            self.managedObjectContext.saveOrCrash()
        }) {
            HStack {
                Image(systemName: "plus")
                Text("Add Set")
            }
        }
    }
    
    /// A custom workout title, or the plan and routine (day) name when the workout came from a routine.
    /// Returns nil when there is no meaningful name, so the header shows just the date.
    private func sessionTitle(for workout: Workout?) -> String? {
        if let title = workout?.title, !title.isEmpty { return title }
        return workout?.workoutPlanAndRoutineTitle()
    }

    @ViewBuilder private var historyWorkoutSets: some View {
        // Each past session is its own card so different days read as clearly separate, not one merged
        // list. The date header opens that whole workout in the History tab.
        ForEach(Array(displayedHistory.enumerated()), id: \.element.objectID) { offset, pastWorkoutExercise in
            let name = sessionTitle(for: pastWorkoutExercise.workout)
            let dateText = Workout.dateFormatter.string(from: pastWorkoutExercise.workout?.start, fallback: "Unknown date")
            Section {
                Button {
                    guard let workout = pastWorkoutExercise.workout else { return }
                    showHistory = false
                    sceneState.historyWorkoutToOpen = workout
                    sceneState.selectedTab = .history
                } label: {
                    // When the workout has a name (routine/plan), it leads and the date sits below it;
                    // otherwise the date leads. The chevron stays on the top line either way.
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text(name ?? dateText)
                                .font(.forgeCaption.weight(.semibold))
                                .foregroundColor(.forgeSecondaryLabel)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.forgeSeparator)
                        }
                        if name != nil {
                            Text(dateText)
                                .font(.caption2)
                                .foregroundColor(.forgeSecondaryLabel)
                                .lineLimit(1)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens this workout in the History tab")
                .listRowInsets(EdgeInsets(top: Theme.Spacing.s, leading: Theme.Spacing.m, bottom: Theme.Spacing.xxs, trailing: Theme.Spacing.m))

                ForEach(self.indexedWorkoutSets(for: pastWorkoutExercise), id: \.1.id) { (index, workoutSet) in
                    WorkoutSetCell(workoutSet: workoutSet, index: index, colorMode: .disabled)
                        .listRowInsets(EdgeInsets(top: 2, leading: Theme.Spacing.m, bottom: 2, trailing: Theme.Spacing.m))
                }
            }
        }

        // Keep the list short by default; reveal the rest on demand.
        if !showAllHistory, workoutExerciseHistory.count > 3 {
            Section {
                Button {
                    withAnimation { showAllHistory = true }
                } label: {
                    Text("Show \(workoutExerciseHistory.count - 3) more")
                        .font(.forgeCaption.weight(.semibold))
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
    
    private var exerciseTitle: String {
        workoutExercise.exercise(in: exerciseStore.exercises)?.title ?? ""
    }

    private func removeExercise() {
        let workout = workoutExercise.workout
        managedObjectContext.delete(workoutExercise)
        workout?.removeFromWorkoutExercises(workoutExercise)
        managedObjectContext.saveOrCrash()
    }

    /// Weight the warm-up ramp is based on: the first working set with a weight, else the most recent
    /// session's first working set, else zero (the sheet then asks for a weight).
    private var warmupBaseWeightKg: Double {
        if let weight = workoutSets(for: workoutExercise)
            .first(where: { $0.tagValue != .warmUp && $0.weightValue > 0 })?.weightValue {
            return weight
        }
        if let history = workoutExerciseHistory.first?.workoutSets?.array as? [WorkoutSet],
           let weight = history.first(where: { $0.weightValue > 0 })?.weightValue {
            return weight
        }
        return 0
    }

    /// Reps the warm-up ramp is based on: the first working set's reps or target reps, else the most
    /// recent session's first working set, else zero (a light default ramp is used).
    private var warmupBaseReps: Int {
        let working = workoutSets(for: workoutExercise).first(where: { $0.tagValue != .warmUp })
        if let reps = working?.repetitionsValue, reps > 0 { return Int(reps) }
        if let target = working?.maxTargetRepetitionsValue ?? working?.minTargetRepetitionsValue, target > 0 {
            return Int(target)
        }
        if let history = workoutExerciseHistory.first?.workoutSets?.array as? [WorkoutSet],
           let reps = history.first(where: { $0.repetitionsValue > 0 })?.repetitionsValue {
            return Int(reps)
        }
        return 0
    }

    /// Inserts the computed warm-up sets before the first working set, so the ramp leads into the
    /// working sets. Each is tagged as a warm-up and left uncompleted for the user to work through.
    private func insertWarmupSets(_ plan: [WarmupSetPlan]) {
        guard !plan.isEmpty, let context = workoutExercise.managedObjectContext else { return }
        let existing = workoutSets(for: workoutExercise)
        let insertIndex = existing.firstIndex(where: { $0.tagValue != .warmUp }) ?? existing.count
        for (offset, warmup) in plan.enumerated() {
            let set = WorkoutSet.create(context: context)
            set.weightValue = warmup.weightKg
            set.repetitionsValue = Int16(warmup.reps)
            set.tagValue = .warmUp
            set.isCompleted = false
            workoutExercise.insertIntoWorkoutSets(set, at: insertIndex + offset)
        }
        Haptics.success()
        context.saveOrCrash()
    }

    /// The exercise name (with its note as a small line right under it) and the options menu.
    private var exerciseHeaderRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exerciseTitle)
                    .font(.forgeHeadline)
                    .foregroundColor(.forgeLabel)
                if hasExerciseNote {
                    Text(workoutExercise.comment ?? "")
                        .font(.forgeCaption.italic())
                        .foregroundColor(.forgeSecondaryLabel)
                        .lineLimit(2)
                        .onTapGesture { showExerciseNote = true }
                }
            }
            Spacer()
            Menu {
                exerciseMenuItems
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.forgeSecondaryLabel)
                    .frame(width: 34, height: 30)
                    .contentShape(Rectangle())
            }
        }
    }

    @ViewBuilder private var exerciseMenuItems: some View {
        Button { showExerciseNote = true } label: {
            Label(hasExerciseNote ? "Edit note" : "Add note", systemImage: "square.and.pencil")
        }
        Button { showHistory = true } label: {
            Label("Previous sessions", systemImage: "clock.arrow.circlepath")
        }
        if isCurrentWorkout {
            Button { showWarmupCalculator = true } label: {
                Label("Warm-up sets", systemImage: "flame")
            }
        }
        if workoutExercise.exercise(in: exerciseStore.exercises) != nil {
            Button { showExerciseInfo = true } label: {
                Label("Exercise info", systemImage: "info.circle")
            }
        }
        if embedded {
            Button(role: .destructive) { removeExercise() } label: {
                Label("Remove exercise", systemImage: "trash")
            }
        }
    }

    /// Sheets, the exercise-info sheet, and the on-appear pre-fill, shared by both layouts. Exercise
    /// info is a sheet (not a hidden NavigationLink) so the card row shows no stray disclosure chevron.
    private func attachingSheets<V: View>(to content: V) -> some View {
        content
            .sheet(isPresented: $showExerciseInfo) {
                if let exercise = workoutExercise.exercise(in: exerciseStore.exercises) {
                    NavigationStack {
                        ExerciseDetailView(exercise: exercise)
                            .environmentObject(self.settingsStore)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") { showExerciseInfo = false }
                                }
                            }
                    }
                }
            }
            .sheet(isPresented: $showWarmupCalculator) {
                NavigationStack {
                    WarmupCalculatorView(
                        weightUnit: settingsStore.weightUnit,
                        initialWorkingWeightKg: warmupBaseWeightKg,
                        initialWorkingReps: warmupBaseReps,
                        onAdd: { insertWarmupSets($0) }
                    )
                }
            }
            .sheet(item: $moreSheetSet) { set in
                NavigationStack {
                    SetMoreView(workoutSet: set, weightUnit: settingsStore.weightUnit, showRPE: settingsStore.showRPE)
                        .navigationBarTitle(Text(set.displayTitle(weightUnit: settingsStore.weightUnit)), displayMode: .inline)
                        .navigationBarItems(
                            leading: Button("Delete set", role: .destructive) {
                                moreSheetSet = nil
                                deleteSet(set)
                            },
                            trailing: Button("Done") { moreSheetSet = nil }
                        )
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showHistory) {
                NavigationStack {
                    List {
                        historyWorkoutSets
                    }
                    .listStyleCompat_InsetGroupedListStyle()
                    .navigationBarTitle("Previous sessions", displayMode: .inline)
                    .navigationBarItems(trailing: Button("Done") { showHistory = false })
                }
            }
            .sheet(isPresented: $showExerciseNote) {
                NavigationStack {
                    ExerciseNoteEditor(workoutExercise: workoutExercise)
                        .navigationBarTitle(Text("Exercise note"), displayMode: .inline)
                        .navigationBarItems(trailing: Button("Done") { showExerciseNote = false })
                }
                .presentationDetents([.medium])
            }
    }

    /// One card per exercise, embedded directly in the current-workout list (no push).
    private var embeddedBody: some View {
        Section {
            attachingSheets(to: exerciseHeaderRow)
            setsHeader
            currentWorkoutSets
            if setsEditable { addSetButton }
        } header: {
            if let sectionHeader { Text(sectionHeader) }
        }
    }

    /// The pushed, full-screen layout used when viewing an exercise from history. Read-only until Edit.
    private var standaloneBody: some View {
        attachingSheets(to:
            VStack(spacing: 0) {
                exerciseNoteSubtitle

                List {
                    Section(header: Text("This session")) {
                        setsHeader
                        currentWorkoutSets
                        if setsEditable { addSetButton }
                    }
                }
                .listStyleCompat_InsetGroupedListStyle()
                .keyboardDoneToolbar()
            }
        )
        .navigationBarTitle(Text(exerciseTitle), displayMode: .inline)
        .navigationBarItems(trailing:
            HStack(spacing: NAVIGATION_BAR_SPACING) {
                Menu {
                    exerciseMenuItems
                } label: {
                    Image(systemName: "ellipsis")
                        .imageScale(.large)
                }
                Button(historyEditMode == .active ? "Done" : "Edit") {
                    Haptics.selection()
                    withAnimation { historyEditMode = historyEditMode == .active ? .inactive : .active }
                }
            }
        )
        .onDisappear {
            self.managedObjectContext.saveOrCrash()
        }
    }

    var body: some View {
        if embedded {
            embeddedBody
        } else {
            standaloneBody
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

/// A small monochrome dot (label color, hairline in the canvas color) that marks a note.
private struct NoteDot: View {
    var body: some View {
        Circle()
            .fill(Color.forgeLabel)
            .frame(width: 7, height: 7)
            .overlay(Circle().strokeBorder(Color.forgeBackground, lineWidth: 1))
    }
}

/// A single set row laid out as a table: number chip (tap for options), the previous session's
/// result, editable weight and reps, and a checkmark to complete it.
private struct ActiveSetRow: View {
    @ObservedObject var workoutSet: WorkoutSet
    let index: Int
    let weightUnit: WeightUnit
    let isCurrentWorkout: Bool
    let isUpNext: Bool
    let showRPE: Bool
    let previousText: String?
    let isEditable: Bool
    var onToggleComplete: () -> Void
    var onMore: () -> Void

    private var hasNote: Bool { !(workoutSet.comment ?? "").isEmpty }

    private var weightText: String {
        let value = WeightUnit.convert(weight: workoutSet.weightValue, from: .metric, to: weightUnit)
        return String(format: "%g", value)
    }

    @FocusState private var focus: Field?
    private enum Field { case weight, reps }

    // The fields edit raw text, so an unset value shows blank (not "0"), an existing value edits
    // smoothly, and a decimal weight can be typed without the value snapping back mid-entry. Text is
    // committed to the set on each change and re-read from the set when it changes elsewhere.
    @State private var weightInput = ""
    @State private var repsInput = ""

    private static let weightFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 3
        f.minimum = 0
        return f
    }()

    private func syncInputsFromModel() {
        weightInput = workoutSet.weight == nil ? "" : (Self.weightFormatter.string(from: NSNumber(value: WeightUnit.convert(weight: workoutSet.weightValue, from: .metric, to: weightUnit))) ?? "")
        repsInput = workoutSet.repetitions == nil ? "" : "\(workoutSet.repetitionsValue)"
    }

    private func commitWeight() {
        let trimmed = weightInput.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            workoutSet.weight = nil
        } else if let number = Self.weightFormatter.number(from: trimmed) {
            workoutSet.weightValue = max(0, min(WeightUnit.convert(weight: number.doubleValue, from: weightUnit, to: .metric), WorkoutSet.MAX_WEIGHT))
        }
    }

    private func commitReps() {
        let trimmed = repsInput.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            workoutSet.repetitions = nil
        } else if let value = Int(trimmed) {
            workoutSet.repetitionsValue = Int16(max(0, min(value, Int(WorkoutSet.MAX_REPETITIONS))))
        }
    }

    // The set number sits in a filled chip tinted by the set type (failure, drop set); a dot marks a
    // set that has a note. Tapping the chip opens the options sheet (tag, note, target, RPE).
    private var numberChip: some View {
        let tint = workoutSet.tagValue?.color
        return Text("\(index)")
            .font(.forgeCaption)
            .foregroundColor(tint ?? .forgeSecondaryLabel)
            .frame(width: 28, height: 28)
            .background(Circle().fill((tint ?? .forgeSecondaryLabel).opacity(tint == nil ? 0.14 : 0.22)))
            .overlay(alignment: .topTrailing) {
                if hasNote { NoteDot() }
            }
    }

    /// The planned rep range from the routine (e.g. "6–8"), shown as a faint hint over the reps field.
    private var targetRepsString: String? {
        WorkoutRoutineSetCell.repetitionIntervalString(
            minRepetitions: workoutSet.minTargetRepetitionsValue.map(Int.init),
            maxRepetitions: workoutSet.maxTargetRepetitionsValue.map(Int.init)
        )
    }

    private func setField(_ text: Binding<String>, field: Field, keyboard: UIKeyboardType, width: CGFloat, targetHint: String? = nil) -> some View {
        ZStack(alignment: .top) {
            TextField("", text: text)
                .keyboardType(keyboard)
                .focused($focus, equals: field)
                .multilineTextAlignment(.center)
                .font(.forgeValue)
                .padding(.vertical, 7)
                .frame(width: width)
            // The planned range sits at the top of the reps field so the entered value stays centered.
            if let targetHint {
                Text(targetHint)
                    .font(.system(size: 10))
                    .foregroundColor(.forgeSecondaryLabel)
                    .allowsHitTesting(false)
                    .padding(.top, 1)
            }
        }
        .frame(width: width)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(.tertiarySystemFill)))
    }

    /// Read-only value shown in place of the editable field (history, outside edit mode).
    private func readValue(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.forgeValue)
            .multilineTextAlignment(.center)
            .padding(.vertical, 7)
            .frame(width: width)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            // The chip opens the options sheet (tag, note, target, RPE) only when the set is editable.
            // In read-only history, tapping a set does nothing until Edit is tapped.
            if isEditable {
                Button(action: onMore) { numberChip }
                    .buttonStyle(.plain)
                    .frame(width: 36)
                    .accessibilityLabel(workoutSet.tagValue.map { "Set \(index), \($0.title). Options" } ?? "Set \(index). Options")
            } else {
                numberChip
                    .frame(width: 36)
                    .accessibilityLabel(workoutSet.tagValue.map { "Set \(index), \($0.title)" } ?? "Set \(index)")
            }

            Text(previousText ?? "—")
                .font(.forgeCaption)
                .foregroundColor(.forgeSecondaryLabel)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)

            if isEditable {
                setField($weightInput, field: .weight, keyboard: .decimalPad, width: 68)
                setField($repsInput, field: .reps, keyboard: .numberPad, width: 60, targetHint: targetRepsString)
            } else {
                readValue(workoutSet.weight == nil ? "—" : weightText, width: 68)
                readValue(workoutSet.repetitions == nil ? "—" : "\(workoutSet.repetitionsValue)", width: 60)
            }

            if isCurrentWorkout {
                Button(action: onToggleComplete) {
                    Image(systemName: workoutSet.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 23))
                        .foregroundColor(workoutSet.isCompleted ? .forgeSuccess : (isUpNext ? .forgeLabel : .forgeSecondaryLabel))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(workoutSet.isCompleted ? "Set completed" : "Complete set")
            }
        }
        .foregroundColor(workoutSet.isCompleted ? .forgeLabel : .forgeSecondaryLabel)
        .onAppear { syncInputsFromModel() }
        .onChange(of: isEditable) { _, editable in if editable { syncInputsFromModel() } }
        .onChange(of: weightInput) { _, _ in commitWeight() }
        .onChange(of: repsInput) { _, _ in commitReps() }
    }
}

/// A focused editor for the whole exercise's note in this session, opened from the ... menu.
private struct ExerciseNoteEditor: View {
    @ObservedObject var workoutExercise: WorkoutExercise

    private var noteBinding: Binding<String> {
        Binding(
            get: { workoutExercise.comment ?? "" },
            set: { workoutExercise.comment = $0.isEmpty ? nil : $0 }
        )
    }

    var body: some View {
        Form {
            Section(footer: Text("A note for this exercise in this session.")) {
                TextField("Note", text: noteBinding, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
        .onDisappear {
            let trimmed = (workoutExercise.comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            workoutExercise.comment = trimmed.isEmpty ? nil : trimmed
            workoutExercise.managedObjectContext?.saveOrCrash()
        }
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
