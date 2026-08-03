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

/// A modal action requested by an exercise card. Embedded cards send the route to the live-workout
/// screen, which owns the only sheet presenter; the standalone history screen hosts the same route at
/// its navigation root.
enum WorkoutExerciseSheetRoute: Identifiable {
    case exerciseInfo(WorkoutExercise)
    case warmupCalculator(WorkoutExercise)
    case setOptions(WorkoutSet)
    case history(WorkoutExercise)
    case exerciseNote(WorkoutExercise)
    case supersetNote(WorkoutExercise)

    var id: String {
        switch self {
        case .exerciseInfo(let exercise): return "exercise-info-\(exercise.id)"
        case .warmupCalculator(let exercise): return "warmup-calculator-\(exercise.id)"
        case .setOptions(let set): return "set-options-\(set.id)"
        case .history(let exercise): return "history-\(exercise.id)"
        case .exerciseNote(let exercise): return "exercise-note-\(exercise.id)"
        case .supersetNote(let exercise): return "superset-note-\(exercise.id)"
        }
    }
}

struct WorkoutExerciseDetailView : View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @Environment(\.editMode) var editMode
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var restTimerStore: RestTimerStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    
    @FetchRequest(fetchRequest: WorkoutExercise.fetchRequest()) var workoutExerciseHistory // will be overwritten in init()
    @ObservedObject var workoutExercise: WorkoutExercise

    @State private var localSheet: WorkoutExerciseSheetRoute?
    // History (standalone) starts read-only unless the screen that opened it was already editing; its
    // Edit button flips this so sets become editable.
    @State private var historyEditMode: EditMode

    /// Sets are editable during the live workout, or in history only after tapping Edit.
    private var setsEditable: Bool { isCurrentWorkout || historyEditMode == .active }

    /// When true, renders as a card embedded in the current-workout list (name header + set table,
    /// no navigation bar). When false, renders as the pushed full-screen view used from history.
    let embedded: Bool
    /// The live workout's normal mode uses a non-recycling ScrollView. In that container this view draws
    /// its own card and separators instead of relying on List section styling.
    let scrollCard: Bool
    /// Both embedded scroll cards and the pushed session editor keep every set row mounted. Only legacy
    /// List-hosted embedded/read-only layouts use native row modifiers.
    private var usesNonRecyclingRows: Bool { scrollCard || !embedded }
    /// Header for the embedded card's section. Set only on the first exercise so the group gets a
    /// single "Exercises" header in the same grouped style as the Characteristics and Attributes ones.
    private let sectionHeader: String?
    /// Set when this exercise is one member of a superset. It then renders its rows without its own card
    /// (the superset card wraps all members in one section) and shows an A / B / C badge before its name.
    private let supersetMember: SupersetMember?
    /// Embedded cards route modal requests to `CurrentWorkoutView`. Nil for the standalone history
    /// layout, which owns a single local presenter at its navigation root.
    private let onPresentSheet: ((WorkoutExerciseSheetRoute) -> Void)?

    /// One exercise's place in a superset: the A / B / C label and where it sits in the round. `isFirst`
    /// drives the extra spacing that separates one member's block from the previous one.
    struct SupersetMember {
        let label: String
        let isFirst: Bool
        let isLast: Bool
    }

    /// [initialEditMode] carries editing in from the screen that opened this one, so a workout opened
    /// for editing keeps its sets editable one level down instead of reverting to read-only.
    init(workoutExercise: WorkoutExercise, embedded: Bool = false, scrollCard: Bool = false, sectionHeader: String? = nil, supersetMember: SupersetMember? = nil, initialEditMode: EditMode = .inactive, onPresentSheet: ((WorkoutExerciseSheetRoute) -> Void)? = nil) {
        self.workoutExercise = workoutExercise
        self.embedded = embedded
        self.scrollCard = scrollCard
        self.sectionHeader = sectionHeader
        self.supersetMember = supersetMember
        self.onPresentSheet = onPresentSheet
        _historyEditMode = State(initialValue: initialEditMode)
        // Diagnostic: this is where each card's history fetch is built, and a freeze log ended inside a
        // live-workout render with no way to tell which card it had reached.
        HangMonitor.note(.exerciseCardBuilt)
        _workoutExerciseHistory = FetchRequest(fetchRequest: workoutExercise.historyFetchRequest)
    }

    private func present(_ sheet: WorkoutExerciseSheetRoute) {
        if let onPresentSheet {
            onPresentSheet(sheet)
        } else {
            localSheet = sheet
        }
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
        HangMonitor.note(.completeSetBegin)
        defer { HangMonitor.note(.completeSetEnd) }
        guard isCurrentWorkout else { return }
        guard set.weightValue >= 0, set.repetitionsValue >= 0 else { return }
        set.isCompleted = true
        let workout = set.workoutExercise?.workout
        workout?.start = workout?.start ?? Date()
        // Do not reorder the exercise on completion: it reflows the list and jumps the scroll position out
        // from under the user. The order stays put where they are looking.
        Haptics.success()
        // Inside a superset the rest timer holds until the last exercise of the round; other exercises
        // start it on completion as before.
        if workoutExercise.startsRestTimerOnSetCompletion {
            HangMonitor.note(.restTimerUpdateBegin)
            restTimerStore.restTimerDuration = restTimerDuration
            restTimerStore.restTimerStart = Date() // start the rest timer
            HangMonitor.note(.restTimerUpdateEnd)
        }
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
                present(.exerciseNote(workoutExercise))
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

    /// True when this exercise is a bodyweight exercise, so its sets enter an added or assisted weight.
    private var exerciseIsBodyweight: Bool {
        workoutExercise.exercise(in: exerciseStore.exercises)?.isBodyweight ?? false
    }

    private var exerciseSets: [WorkoutSet] {
        workoutExercise.workoutSets?.array as? [WorkoutSet] ?? []
    }

    /// The workout is ad-hoc (not started from a routine), so the added/assisted choice is made here.
    /// A routine-started workout inherits the routine's choice and hides the control.
    private var isAdHocWorkout: Bool {
        workoutExercise.workout?.workoutRoutine == nil
    }

    /// Flipping the mode re-signs every set's added weight, keeping the magnitudes, and saves. Legacy sets
    /// (value still in the plain weight field) fall back to it, so their amount is preserved not zeroed.
    private func applyBodyweightMode(assisted: Bool) {
        workoutExercise.assistedValue = assisted
        for set in exerciseSets {
            let magnitude = abs(set.addedWeightValue ?? set.weightValue)
            set.addedWeightValue = assisted ? -magnitude : magnitude
        }
        managedObjectContext.saveOrCrash()
    }

    private var bodyweightModeRow: some View {
        // The displayed value is inferred from existing set signs when the mode was never set, so showing
        // the control never writes to the model (which would publish a change during the update pass). It
        // only persists when the user actually toggles it.
        Picker("Weight kind", selection: Binding(
            get: { workoutExercise.assisted?.boolValue ?? exerciseSets.contains { ($0.addedWeightValue ?? 0) < 0 } },
            set: { applyBodyweightMode(assisted: $0) }
        )) {
            Text("Added").tag(false)
            Text("Assisted").tag(true)
        }
        .pickerStyle(.segmented)
        .listRowInsets(EdgeInsets(top: 4, leading: Theme.Spacing.m, bottom: 6, trailing: Theme.Spacing.m))
    }

    /// Column headers above the set rows (Set, Previous, kg, Reps).
    private var setsHeader: some View {
        HStack(spacing: Theme.Spacing.s) {
            Text("Set").frame(width: 36)
            Text("Previous").frame(maxWidth: .infinity, alignment: .center)
            Text(settingsStore.weightUnit.unit.symbol).frame(width: 68)
            Text("Reps").frame(width: 60)
            // Matches the 44pt complete-set button so the kg and reps headers sit over their boxes.
            if isCurrentWorkout { Color.clear.frame(width: 44, height: 0) }
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

    /// The next-time target weight planned on the matching set last session, formatted for the display
    /// unit. Shown as a faint hint in the weight box (both an indicator and a fill guide), the same way
    /// the routine's rep range fills the reps box.
    private func targetWeightHint(atZeroBased index: Int) -> String? {
        guard index >= 0,
              let sets = workoutExerciseHistory.first?.workoutSets?.array as? [WorkoutSet],
              index < sets.count,
              let target = sets[index].targetWeightValue, target > 0 else { return nil }
        return settingsStore.weightUnit.numberFormatter.string(from: WeightUnit.convert(weight: target, from: .metric, to: settingsStore.weightUnit) as NSNumber)
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
            let row = ActiveSetRow(
                workoutSet: workoutSet,
                index: index,
                weightUnit: settingsStore.weightUnit,
                isCurrentWorkout: isCurrentWorkout,
                isUpNext: firstUncompletedSet == workoutSet,
                showRPE: settingsStore.showRPE,
                isBodyweight: exerciseIsBodyweight,
                assisted: workoutExercise.assistedValue,
                previousText: previousPerformance(atZeroBased: index - 1),
                weightPlaceholder: targetWeightHint(atZeroBased: index - 1) ?? "",
                isEditable: setsEditable,
                onToggleComplete: {
                    HangMonitor.note(.setCompletionToggled)
                    toggleComplete(workoutSet)
                },
                onMore: {
                    HangMonitor.note(.setOptionsOpened)
                    present(.setOptions(workoutSet))
                }
            )
            if usesNonRecyclingRows {
                ForgeSwipeToDeleteRow(onDelete: { deleteSet(workoutSet) }) {
                    row
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.vertical, 3)
                        .overlay(alignment: .bottom) {
                            ForgeListSeparator().padding(.horizontal, Theme.Layout.insetGroupedRowInset)
                        }
                }
            } else {
                row
                    // Tighter vertical insets so the set rows sit closer together, less separation between sets.
                    .listRowInsets(EdgeInsets(top: 3, leading: Theme.Spacing.m, bottom: 3, trailing: Theme.Spacing.m))
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
    }
    
    private var addSetButton: some View {
        Button(action: {
            Haptics.impact(.light)
            let workoutSet = WorkoutSet.create(context: self.workoutExercise.managedObjectContext!)
            workoutSet.workoutExercise = self.workoutExercise
            if self.workoutExercise.exercise(in: exerciseStore.exercises)?.isBodyweight == true {
                // Mark it as a bodyweight set (addedWeight 0, not nil) so it reads as BW before it is edited.
                workoutSet.addedWeightValue = 0
            }
            if !self.isCurrentWorkout {
                // don't allow uncompleted sets if not in current workout
                workoutSet.isCompleted = true
            }
            // New sets start empty; the previous session is shown as a reference, not pre-filled.
            self.managedObjectContext.saveOrCrash()
        }) {
            HStack {
                Image(systemName: "plus")
                Text("Add set")
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
        // If this left a superset with a single member, clear that stale grouping.
        workout?.normalizeSupersets()
        managedObjectContext.saveOrCrash()
    }

    /// The exercise name (with its note as a small line right under it) and the options menu.
    private var exerciseHeaderRow: some View {
        HStack(alignment: .firstTextBaseline) {
            if let member = supersetMember {
                Text(member.label)
                    .font(.forgeCaption.weight(.bold))
                    .foregroundColor(.forgeLabel)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.forgeSeparator))
                    .accessibilityLabel("Superset position \(member.label)")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(exerciseTitle)
                    .font(.forgeHeadline)
                    .foregroundColor(.forgeLabel)
                if hasExerciseNote {
                    Text(workoutExercise.comment ?? "")
                        .font(.forgeCaption.italic())
                        .foregroundColor(.forgeSecondaryLabel)
                        .lineLimit(2)
                        .onTapGesture { present(.exerciseNote(workoutExercise)) }
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
        // Separate a following superset member from the one above it, so A and B read as distinct blocks.
        .padding(.top, (supersetMember.map { !$0.isFirst } ?? false) ? Theme.Spacing.l : 0)
    }

    @ViewBuilder private var exerciseMenuItems: some View {
        Button {
            HangMonitor.note(.exerciseNoteOpened)
            present(.exerciseNote(workoutExercise))
        } label: {
            Label(hasExerciseNote ? "Change note" : "Add note", systemImage: "square.and.pencil")
        }
        Button {
            HangMonitor.note(.previousSessionsOpened)
            present(.history(workoutExercise))
        } label: {
            Label("Previous sessions", systemImage: "clock.arrow.circlepath")
        }
        if isCurrentWorkout {
            Button { present(.warmupCalculator(workoutExercise)) } label: {
                Label("Warm-up sets", systemImage: "flame")
            }
        }
        if workoutExercise.exercise(in: exerciseStore.exercises) != nil {
            Button { present(.exerciseInfo(workoutExercise)) } label: {
                Label("Exercise info", systemImage: "info.circle")
            }
        }
        if embedded {
            Button(role: .destructive) { removeExercise() } label: {
                Label("Remove exercise", systemImage: "trash")
            }
        }
    }

    /// The rows of an embedded exercise: name header, column headers, set table, and add-set. Shared by
    /// the standalone card and by a superset member (which the superset card wraps into one section).
    @ViewBuilder private var embeddedContent: some View {
        exerciseHeaderRow
        if exerciseIsBodyweight && setsEditable && isAdHocWorkout { bodyweightModeRow }
        setsHeader
        currentWorkoutSets
        if setsEditable { addSetButton }
    }

    /// One card per exercise, embedded directly in the current-workout list (no push).
    private var embeddedBody: some View {
        Section {
            embeddedContent
        } header: {
            if let sectionHeader { Text(sectionHeader) }
        }
    }

    /// The same exercise rows as the List version, kept alive together inside one explicit card. A plain
    /// VStack is deliberate: LazyVStack/List recycling was repeatedly constructing and dismantling the
    /// focused numeric fields immediately before the permanent main-thread block.
    private var scrollRows: some View {
        VStack(spacing: 0) {
            exerciseHeaderRow
                .padding(.horizontal, Theme.Layout.insetGroupedRowInset)
                .frame(minHeight: Theme.Layout.minTapTarget)
            ForgeListSeparator().padding(.horizontal, Theme.Layout.insetGroupedRowInset)
            if exerciseIsBodyweight && setsEditable && isAdHocWorkout {
                bodyweightModeRow
                    .padding(.horizontal, Theme.Spacing.m)
                    .frame(minHeight: Theme.Layout.minTapTarget)
                ForgeListSeparator().padding(.horizontal, Theme.Layout.insetGroupedRowInset)
            }
            setsHeader
                .padding(.horizontal, Theme.Spacing.m)
                .frame(minHeight: Theme.Layout.minTapTarget)
            ForgeListSeparator().padding(.horizontal, Theme.Layout.insetGroupedRowInset)
            currentWorkoutSets
            if setsEditable {
                addSetButton
                    .padding(.horizontal, Theme.Layout.insetGroupedRowInset)
                    .frame(minHeight: Theme.Layout.minTapTarget)
            }
        }
    }

    private var scrollCardBody: some View {
        scrollRows
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .fill(Color.forgeSurface)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
    }

    private var standaloneSessionCard: some View {
        VStack(spacing: 0) {
            if exerciseIsBodyweight && setsEditable && isAdHocWorkout {
                bodyweightModeRow
                    .padding(.horizontal, Theme.Spacing.m)
                    .frame(minHeight: Theme.Layout.minTapTarget)
                ForgeListSeparator().padding(.horizontal, Theme.Layout.insetGroupedRowInset)
            }
            setsHeader
                .padding(.horizontal, Theme.Spacing.m)
                .frame(minHeight: Theme.Layout.minTapTarget)
            ForgeListSeparator().padding(.horizontal, Theme.Layout.insetGroupedRowInset)
            currentWorkoutSets
            if setsEditable {
                addSetButton
                    .padding(.horizontal, Theme.Layout.insetGroupedRowInset)
                    .frame(minHeight: Theme.Layout.minTapTarget)
            }
        }
        .forgeCard()
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
    }

    /// The pushed, full-screen layout used when viewing an exercise from history. Read-only until Edit.
    /// A non-lazy stack keeps an active numeric field alive if the user scrolls during editing.
    private var standaloneBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                exerciseNoteSubtitle
                    .padding(.horizontal, Theme.Layout.insetGroupedRowInset)
                Text("This session")
                    .font(.forgeHeadline)
                    .foregroundColor(.forgeSecondaryLabel)
                    .padding(.horizontal, Theme.Layout.insetGroupedRowInset)
                standaloneSessionCard
            }
            .padding(.horizontal, Theme.Layout.insetGroupedRowInset)
            .padding(.top, Theme.Spacing.l)
            .padding(.bottom, Theme.Layout.bottomScrollClearance)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color.forgeBackground.ignoresSafeArea())
        .navigationBarTitle(Text(exerciseTitle), displayMode: .inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
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
        }
        .onDisappear {
            self.managedObjectContext.saveOrCrash()
        }
        .sheet(item: $localSheet) { route in
            WorkoutExerciseSheetContent(route: route) { localSheet = nil }
        }
    }

    var body: some View {
        Group {
            if embedded {
                if scrollCard {
                    if supersetMember != nil {
                        scrollRows
                    } else {
                        scrollCardBody
                    }
                } else if supersetMember != nil {
                    // The superset card provides the section and the shared header, so a member contributes
                    // only its rows.
                    embeddedContent
                } else {
                    embeddedBody
                }
            } else {
                standaloneBody
            }
        }
        .onAppear { HangMonitor.note(.exerciseCardAppeared) }
        .onDisappear { HangMonitor.note(.exerciseCardDisappeared) }
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

/// Builds the selected exercise sheet independently of the row that requested it. Keeping this content
/// behind one screen-level `.sheet(item:)` means a Core Data refresh can rebuild every row without
/// invalidating UIKit's presenter.
struct WorkoutExerciseSheetContent: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var exerciseStore: ExerciseStore

    let route: WorkoutExerciseSheetRoute
    let onDismiss: () -> Void

    @ViewBuilder var body: some View {
        switch route {
        case .exerciseInfo(let workoutExercise):
            if let exercise = workoutExercise.exercise(in: exerciseStore.exercises) {
                NavigationStack {
                    ExerciseDetailView(exercise: exercise)
                        .environmentObject(settingsStore)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done", action: onDismiss).fontWeight(.semibold)
                            }
                        }
                }
            }

        case .warmupCalculator(let workoutExercise):
            WorkoutWarmupSheet(workoutExercise: workoutExercise, weightUnit: settingsStore.weightUnit)

        case .setOptions(let set):
            NavigationStack {
                SetMoreView(workoutSet: set, weightUnit: settingsStore.weightUnit, showRPE: settingsStore.showRPE)
                    .navigationBarTitle(Text(set.displayTitle(weightUnit: settingsStore.weightUnit)), displayMode: .inline)
                    .navigationBarItems(
                        leading: Button("Delete set", role: .destructive) {
                            onDismiss()
                            delete(set)
                        },
                        trailing: Button("Done", action: onDismiss).fontWeight(.semibold)
                    )
            }
            .presentationDetents([.large])

        case .history(let workoutExercise):
            WorkoutExerciseHistorySheet(workoutExercise: workoutExercise, onDismiss: onDismiss)

        case .exerciseNote(let workoutExercise):
            NavigationStack {
                ExerciseNoteEditor(workoutExercise: workoutExercise)
                    .navigationBarTitle(Text("Exercise note"), displayMode: .inline)
                    .navigationBarItems(trailing: Button("Done", action: onDismiss).fontWeight(.semibold))
            }
            .presentationDetents([.medium])

        case .supersetNote(let anchor):
            NavigationStack {
                SupersetNoteEditor(anchor: anchor)
                    .navigationBarTitle("Superset note", displayMode: .inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done", action: onDismiss).fontWeight(.semibold)
                        }
                    }
            }
            .presentationDetents([.medium])
        }
    }

    private func delete(_ set: WorkoutSet) {
        guard let context = set.managedObjectContext else { return }
        let exercise = set.workoutExercise
        context.delete(set)
        exercise?.removeFromWorkoutSets(set)
        context.saveOrCrash()
    }
}

/// Owns the fetched history needed to seed and apply a warm-up plan. It lives in sheet content instead
/// of the exercise row, so the route remains valid while the live list refreshes underneath it.
private struct WorkoutWarmupSheet: View {
    @FetchRequest private var workoutExerciseHistory: FetchedResults<WorkoutExercise>
    @ObservedObject var workoutExercise: WorkoutExercise
    let weightUnit: WeightUnit

    init(workoutExercise: WorkoutExercise, weightUnit: WeightUnit) {
        self.workoutExercise = workoutExercise
        self.weightUnit = weightUnit
        _workoutExerciseHistory = FetchRequest(fetchRequest: workoutExercise.historyFetchRequest)
    }

    private var workoutSets: [WorkoutSet] {
        workoutExercise.workoutSets?.array as? [WorkoutSet] ?? []
    }

    /// Prefer the last session's first working set. Fall back to this session's first working set and
    /// its entered or planned repetitions.
    private var baseSet: (weightKg: Double, reps: Int) {
        if let history = workoutExerciseHistory.first?.workoutSets?.array as? [WorkoutSet],
           let set = history.first(where: { $0.tagValue != .warmUp && ($0.weightValue > 0 || $0.repetitionsValue > 0) }) {
            return (set.weightValue, Int(set.repetitionsValue))
        }
        if let set = workoutSets.first(where: { $0.tagValue != .warmUp }) {
            let reps = set.repetitionsValue > 0
                ? Int(set.repetitionsValue)
                : Int(set.maxTargetRepetitionsValue ?? set.minTargetRepetitionsValue ?? 0)
            return (set.weightValue, reps)
        }
        return (0, 0)
    }

    var body: some View {
        NavigationStack {
            WarmupCalculatorView(
                weightUnit: weightUnit,
                initialWorkingWeightKg: baseSet.weightKg,
                initialWorkingReps: baseSet.reps,
                onAdd: insertWarmupSets
            )
        }
    }

    private func insertWarmupSets(_ plan: [WarmupSetPlan]) {
        guard !plan.isEmpty, let context = workoutExercise.managedObjectContext else { return }
        for set in workoutSets {
            guard set.tagValue == .warmUp else { break }
            if !set.isCompleted {
                context.delete(set)
                workoutExercise.removeFromWorkoutSets(set)
            }
        }
        let existing = workoutSets
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
}

/// Previous sessions shown by the history route. This view owns its fetch and expansion state, rather
/// than borrowing state from the exercise card underneath the sheet.
private struct WorkoutExerciseHistorySheet: View {
    @EnvironmentObject private var sceneState: SceneState
    @FetchRequest private var workoutExerciseHistory: FetchedResults<WorkoutExercise>

    let onDismiss: () -> Void
    @State private var showAllHistory = false

    init(workoutExercise: WorkoutExercise, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        _workoutExerciseHistory = FetchRequest(fetchRequest: workoutExercise.historyFetchRequest)
    }

    private var displayedHistory: [WorkoutExercise] {
        let all = Array(workoutExerciseHistory)
        return showAllHistory ? all : Array(all.prefix(3))
    }

    private func indexedWorkoutSets(for workoutExercise: WorkoutExercise) -> [(Int, WorkoutSet)] {
        let sets = workoutExercise.workoutSets?.array as? [WorkoutSet] ?? []
        return sets.enumerated().map { ($0 + 1, $1) }
    }

    private func sessionTitle(for workout: Workout?) -> String? {
        if let title = workout?.title, !title.isEmpty { return title }
        return workout?.workoutPlanAndRoutineTitle()
    }

    var body: some View {
        NavigationStack {
            List {
                historyRows
            }
            .listStyleCompat_InsetGroupedListStyle()
            .navigationBarTitle("Previous sessions", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done", action: onDismiss).fontWeight(.semibold))
        }
    }

    @ViewBuilder private var historyRows: some View {
        ForEach(displayedHistory) { pastWorkoutExercise in
            let name = sessionTitle(for: pastWorkoutExercise.workout)
            let dateText = Workout.dateFormatter.string(from: pastWorkoutExercise.workout?.start, fallback: "Unknown date")
            Section {
                Button {
                    guard let workout = pastWorkoutExercise.workout else { return }
                    onDismiss()
                    sceneState.historyWorkoutToOpen = workout
                    sceneState.selectedTab = .history
                } label: {
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

                ForEach(indexedWorkoutSets(for: pastWorkoutExercise), id: \.1.id) { index, workoutSet in
                    WorkoutSetCell(workoutSet: workoutSet, index: index, colorMode: .disabled)
                        .listRowInsets(EdgeInsets(top: 2, leading: Theme.Spacing.m, bottom: 2, trailing: Theme.Spacing.m))
                }
            }
        }

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
}

/// Edits the note shared by a whole superset. Editing an anchor member writes the note to every member of
/// the group, so it survives reordering within the group.
private struct SupersetNoteEditor: View {
    @ObservedObject var anchor: WorkoutExercise
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

/// A single set row laid out as a table: number chip (tap for options), the previous session's
/// result, editable weight and reps, and a checkmark to complete it.
private struct ActiveSetRow: View {
    @ObservedObject var workoutSet: WorkoutSet
    let index: Int
    let weightUnit: WeightUnit
    let isCurrentWorkout: Bool
    let isUpNext: Bool
    let showRPE: Bool
    /// When true, the weight field enters an added or assisted amount (stored in addedWeight) rather than
    /// an absolute weight, and `assisted` decides its sign.
    var isBodyweight: Bool = false
    var assisted: Bool = false
    let previousText: String?
    /// The planned next-time target weight, shown as a faint hint in the weight box. Empty when none.
    var weightPlaceholder: String = ""
    let isEditable: Bool
    var onToggleComplete: () -> Void
    var onMore: () -> Void

    private var hasNote: Bool { !(workoutSet.comment ?? "").isEmpty }

    /// True when this set carries a weight planned last session (shown as the box hint), so the row can
    /// mark that the value comes from the previous workout.
    private var hasPreviousValue: Bool { !weightPlaceholder.isEmpty }

    private var weightText: String {
        let value = WeightUnit.convert(weight: workoutSet.weightValue, from: .metric, to: weightUnit)
        return Self.compactWeightFormatter.string(from: NSNumber(value: value)) ?? String(format: "%g", value)
    }

    /// Read-only weight display for a bodyweight set: BW, +added, or -assisted. Sets logged before this
    /// exercise became bodyweight keep their value in the plain weight field, so fall back to it and show
    /// that value (as a weighted amount) instead of blank.
    private var bodyweightReadText: String {
        let added = workoutSet.addedWeightValue ?? workoutSet.weightValue
        if added == 0 { return "BW" }
        let magnitude = WeightUnit.convert(weight: abs(added), from: .metric, to: weightUnit)
        let text = Self.compactWeightFormatter.string(from: NSNumber(value: magnitude)) ?? String(format: "%g", magnitude)
        return (added > 0 ? "+" : "-") + text
    }

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

    /// Keeps converted weights readable in a narrow idle box (for example 115.74 rather than an
    /// ellipsis). The unrounded three-decimal input remains in `weightInput` and returns on focus.
    private static let compactWeightFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    private var compactWeightText: String? {
        guard !weightInput.isEmpty, let number = Self.weightFormatter.number(from: weightInput) else { return nil }
        return Self.compactWeightFormatter.string(from: number)
    }

    private func syncInputsFromModel() {
        if isBodyweight {
            // The field holds the non-negative magnitude; a pure bodyweight set (0) shows blank. Fall back
            // to the legacy weight for sets logged before this exercise became bodyweight.
            let magnitude = abs(workoutSet.addedWeightValue ?? workoutSet.weightValue)
            weightInput = magnitude == 0 ? "" : (Self.weightFormatter.string(from: NSNumber(value: WeightUnit.convert(weight: magnitude, from: .metric, to: weightUnit))) ?? "")
        } else {
            weightInput = workoutSet.weight == nil ? "" : (Self.weightFormatter.string(from: NSNumber(value: WeightUnit.convert(weight: workoutSet.weightValue, from: .metric, to: weightUnit))) ?? "")
        }
        repsInput = workoutSet.repetitions == nil ? "" : "\(workoutSet.repetitionsValue)"
    }

    private func commitWeight() {
        HangMonitor.note(.weightCommitted)
        let trimmed = weightInput.trimmingCharacters(in: .whitespaces)
        if isBodyweight {
            // Blank means a pure bodyweight set (added 0), not a normal set: keep addedWeight non-nil so it
            // stays bodyweight. The sign comes from the exercise's added/assisted mode.
            if trimmed.isEmpty {
                workoutSet.addedWeightValue = 0
            } else if let number = Self.weightFormatter.number(from: trimmed) {
                let magnitude = max(0, min(WeightUnit.convert(weight: number.doubleValue, from: weightUnit, to: .metric), WorkoutSet.MAX_WEIGHT))
                workoutSet.addedWeightValue = assisted ? -magnitude : magnitude
            }
            return
        }
        if trimmed.isEmpty {
            workoutSet.weight = nil
        } else if let number = Self.weightFormatter.number(from: trimmed) {
            workoutSet.weightValue = max(0, min(WeightUnit.convert(weight: number.doubleValue, from: weightUnit, to: .metric), WorkoutSet.MAX_WEIGHT))
        }
    }

    private func commitReps() {
        HangMonitor.note(.repsCommitted)
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
        ForgeSetNumberChip(
            index: index,
            tint: workoutSet.tagValue?.color,
            showsNote: hasNote,
            showsPreviousValue: hasPreviousValue
        )
    }

    /// The planned rep range from the routine (e.g. "6–8"), shown as a faint hint over the reps field.
    private var targetRepsString: String? {
        WorkoutRoutineSetCell.repetitionIntervalString(
            minRepetitions: workoutSet.minTargetRepetitionsValue.map(Int.init),
            maxRepetitions: workoutSet.maxTargetRepetitionsValue.map(Int.init)
        )
    }

    // Briefly outlined in red when the user tries to complete a set with this field empty.
    @State private var weightInvalid = false
    @State private var repsInvalid = false

    /// A value box, entered from the right. A planned rep range (when there is one) shows as the
    /// placeholder inside the box, so it disappears once a value is typed and never floats out of place.
    /// The field fills the box, so tapping anywhere in it opens the keyboard.
    private func setField(_ text: Binding<String>, keyboard: UIKeyboardType, width: CGFloat, accessibilityLabel: String, placeholder: String = "", displayText: String? = nil, invalid: Bool = false, onCommit: @escaping () -> Void = {}) -> some View {
        RightAlignedNumberField(
            text: text,
            placeholder: placeholder,
            keyboardType: keyboard,
            displayText: displayText,
            accessibilityLabel: accessibilityLabel,
            onCommit: onCommit
        )
            .forgeSetValueBox(width: width, invalid: invalid)
    }

    /// A set needs a weight and reps before it can be completed. Bodyweight sets can enter 0 for weight;
    /// what is blocked is completing an empty field.
    private func attemptComplete() {
        HangMonitor.note(.attemptCompleteBegin)
        defer { HangMonitor.note(.attemptCompleteEnd) }
        if workoutSet.isCompleted {
            onToggleComplete()
            return
        }
        // The field may still be focused (its onCommit hasn't fired), so persist the typed values first.
        commitWeight()
        commitReps()
        // A bodyweight set needs no weight entry (blank means a pure bodyweight rep); only reps are required.
        let hasWeight = isBodyweight || !weightInput.trimmingCharacters(in: .whitespaces).isEmpty
        let hasReps = (Int(repsInput.trimmingCharacters(in: .whitespaces)) ?? 0) > 0
        guard hasWeight, hasReps else {
            HangMonitor.note(.completeRefused)
            Haptics.error()
            withAnimation(.easeInOut(duration: 0.15)) {
                weightInvalid = !hasWeight
                repsInvalid = !hasReps
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    weightInvalid = false
                    repsInvalid = false
                }
            }
            return
        }
        onToggleComplete()
    }

    /// Read-only value shown in place of the editable field (history, outside edit mode), right-aligned
    /// to match the editable box so a row keeps its column positions across Edit.
    private func readValue(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.forgeValue)
            .frame(width: width, height: ForgeSetRowStyle.numberBoxHeight)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            // The chip opens the set's details (tag, note, target, RPE), including in read-only history, so
            // a note can be read by tapping the set without entering Edit. Full row-height tap target so
            // the chip is easy to hit mid-workout, not just the 28pt circle.
            Button(action: onMore) { numberChip }
                .buttonStyle(.plain)
                .frame(width: 36, height: ForgeSetRowStyle.numberBoxHeight)
                .contentShape(Rectangle())
                .accessibilityLabel(workoutSet.tagValue.map { "Set \(index), \($0.title). Details" } ?? "Set \(index). Details")

            Text(previousText ?? "—")
                .font(.forgeSupportingValue)
                .foregroundColor(.forgeSecondaryLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .center)

            if isEditable {
                setField($weightInput, keyboard: .decimalPad, width: 68, accessibilityLabel: "Set \(index) weight", placeholder: weightPlaceholder, displayText: compactWeightText, invalid: weightInvalid, onCommit: commitWeight)
                setField($repsInput, keyboard: .numberPad, width: 60, accessibilityLabel: "Set \(index) repetitions", placeholder: targetRepsString ?? "", invalid: repsInvalid, onCommit: commitReps)
            } else {
                readValue(isBodyweight ? bodyweightReadText : (workoutSet.weight == nil ? "—" : weightText), width: 68)
                readValue(workoutSet.repetitions == nil ? "—" : "\(workoutSet.repetitionsValue)", width: 60)
            }

            if isCurrentWorkout {
                Button(action: attemptComplete) {
                    Image(systemName: workoutSet.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 23))
                        .foregroundColor(workoutSet.isCompleted ? .forgeSuccess : (isUpNext ? .forgeLabel : .forgeSecondaryLabel))
                        // A 44pt tap target (Apple's minimum) around the 23pt glyph, so completing a set
                        // is forgiving when tired or moving.
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(workoutSet.isCompleted ? "Set completed" : "Complete set")
            }
        }
        .foregroundColor(workoutSet.isCompleted ? .forgeLabel : .forgeSecondaryLabel)
        .onAppear {
            HangMonitor.note(.setRowAppeared)
            syncInputsFromModel()
        }
        .onDisappear { HangMonitor.note(.setRowDisappeared) }
        .onChange(of: isEditable) { _, editable in if editable { syncInputsFromModel() } }
        // The values commit when the field resigns focus (onCommit on each setField), not per keystroke, so
        // typing a set does not write to Core Data on every character and re-render the whole live workout.
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
