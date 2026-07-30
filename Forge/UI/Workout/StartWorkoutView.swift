//
//  StartWorkoutView.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 19.07.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import CoreData
import WorkoutDataKit
import os.log

struct StartWorkoutView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    
    @State private var quote = Quotes.quotes.randomElement()

    @State private var offsetsToDelete: IndexSet?

    // Tapping a routine opens a menu (start, edit, duplicate, move, share, delete) anchored to the row.
    @State private var routineToEdit: WorkoutRoutine?
    @State private var activityItems: [Any]?
    
    @FetchRequest(fetchRequest: StartWorkoutView.fetchRequest) var workoutPlans

    @FetchRequest(fetchRequest: StartWorkoutView.standaloneRoutinesFetchRequest) var standaloneRoutines

    static var fetchRequest: NSFetchRequest<WorkoutPlan> {
        let request: NSFetchRequest<WorkoutPlan> = WorkoutPlan.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WorkoutPlan.title, ascending: false)]
        return request
    }

    // Routines that belong to no plan, shown in their own section.
    static var standaloneRoutinesFetchRequest: NSFetchRequest<WorkoutRoutine> {
        let request = NSFetchRequest<WorkoutRoutine>(entityName: "WorkoutRoutine")
        request.predicate = NSPredicate(format: "workoutPlan == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WorkoutRoutine.title, ascending: true)]
        return request
    }

    // The plus is the single entry point: start a workout, or create a routine or a plan.
    private var addMenu: some View {
        Menu {
            Button {
                Haptics.impact(.medium)
                Workout.create(context: self.managedObjectContext).startOrCrash()
            } label: {
                Label("New workout", systemImage: "figure.strengthtraining.traditional")
            }
            Button {
                self.newRoutine()
            } label: {
                Label("New routine", systemImage: "square.stack.3d.up.fill")
            }
            Button {
                self.newWorkoutPlan()
            } label: {
                Label("New workout plan", systemImage: "list.bullet.rectangle")
            }
        } label: {
            Image(systemName: "plus")
                .imageScale(.large)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .forgeGlassCircle()
        }
        .accessibilityLabel("Add")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // A big title with the plus on the right, matching the dashboard header.
                HStack(alignment: .center) {
                    Text("Workout")
                        .font(.forgeGreeting)
                        .foregroundColor(.forgeLabel)
                    Spacer()
                    addMenu
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.xxl)
                .padding(.bottom, Theme.Spacing.m)

                List {
                    if !standaloneRoutines.isEmpty {
                        Section(header: Text("Routines")) {
                            ForEach(standaloneRoutines) { routine in
                                RoutineMenuRow(routine: routine, allPlans: Array(workoutPlans), onStart: { start(routine: $0) }, onEdit: { routineToEdit = $0 }, onShare: { shareRoutine($0) })
                            }
                            .onDelete { deleteStandaloneRoutines($0) }
                        }
                    }
                    ForEach(workoutPlans) { workoutPlan in
                        Section {
                            WorkoutPlanCell(workoutPlan: workoutPlan)
                            WorkoutPlanRoutines(workoutPlan: workoutPlan, allPlans: Array(workoutPlans), onStart: { start(routine: $0) }, onEdit: { routineToEdit = $0 }, onShare: { shareRoutine($0) })
                                .deleteDisabled(true)
                        }
                        // The routine wells carry their own edges, so the list separators between them are
                        // redundant and read as non-native.
                        .listRowSeparator(.hidden)
                    }
                    .onDelete { offsets in
                        if self.needsConfirmBeforeDelete(offsets: offsets) {
                            self.offsetsToDelete = offsets
                        } else {
                            self.deleteAt(offsets: offsets)
                        }
                    }
                }
                .listStyleCompat_InsetGroupedListStyle()
            }
            .background(Color.forgeBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $routineToEdit) { routine in
                WorkoutRoutineView(workoutRoutine: routine)
            }
            .overlay(ActivitySheet(activityItems: $activityItems))
            .alert("Delete workout plan?", isPresented: Binding(get: { offsetsToDelete != nil }, set: { if !$0 { offsetsToDelete = nil } })) {
                Button("Delete", role: .destructive) {
                    if let offsets = offsetsToDelete { self.deleteAt(offsets: offsets) }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    /// Start a workout from a routine. Animated so the live workout slides in rather than snapping.
    /// Write the routine to a JSON file and open the share sheet.
    private func shareRoutine(_ routine: WorkoutRoutine) {
        do {
            let data = try WorkoutDataExchange.export(routines: [routine])
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("routine.json")
            try data.write(to: url)
            self.activityItems = [url]
        } catch {
            os_log("Could not export routine as JSON: %@", type: .error, error.localizedDescription)
        }
    }

    private func start(routine: WorkoutRoutine) {
        Haptics.impact(.medium)
        withAnimation(.smooth) {
            routine.createWorkout(context: self.managedObjectContext).startOrCrash()
        }
    }

    private func newWorkoutPlan() {
        _ = WorkoutPlan.create(context: managedObjectContext)
        managedObjectContext.saveOrCrash()
    }

    /// Create a routine that belongs to no plan and open it for editing.
    private func newRoutine() {
        let routine = WorkoutRoutine.create(context: managedObjectContext)
        managedObjectContext.saveOrCrash()
        routineToEdit = routine
    }

    private func deleteStandaloneRoutines(_ offsets: IndexSet) {
        for i in offsets {
            managedObjectContext.delete(standaloneRoutines[i])
        }
        managedObjectContext.saveOrCrash()
    }
    
    /// Resturns `true` if at least one workout plan has workout routines
    private func needsConfirmBeforeDelete(offsets: IndexSet) -> Bool {
        for index in offsets {
            if workoutPlans[index].workoutRoutines?.count ?? 0 != 0 {
                return true
            }
        }
        return false
    }
    
    private func deleteAt(offsets: IndexSet) {
        let workoutPlans = self.workoutPlans
        for i in offsets {
            self.managedObjectContext.delete(workoutPlans[i])
        }
        self.managedObjectContext.saveOrCrash()
    }
}

private struct WorkoutPlanCell: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    
    @ObservedObject var workoutPlan: WorkoutPlan
    
    var body: some View {
        NavigationLink(destination: WorkoutPlanView(workoutPlan: workoutPlan)) {
            Text(workoutPlan.displayTitle)
                .font(.headline)
            .contextMenu {
                Button(action: {
                    _ = self.workoutPlan.duplicate(context: self.managedObjectContext)
                    self.managedObjectContext.saveOrCrash()
                }) {
                    Text("Duplicate")
                    Image(systemName: "doc.on.doc")
                }
                Button(action: {
                    self.managedObjectContext.delete(self.workoutPlan)
                    self.managedObjectContext.saveOrCrash()
                }) {
                    Text("Delete")
                    Image(systemName: "trash")
                }
            }
        }
    }
}

private struct WorkoutPlanRoutines: View {
    @ObservedObject var workoutPlan: WorkoutPlan

    /// All plans, so a routine can be moved to another one.
    var allPlans: [WorkoutPlan]
    var onStart: (WorkoutRoutine) -> Void
    var onEdit: (WorkoutRoutine) -> Void
    var onShare: (WorkoutRoutine) -> Void

    private var workoutRoutines: [WorkoutRoutine] {
        workoutPlan.workoutRoutines?.array as? [WorkoutRoutine] ?? []
    }

    var body: some View {
        ForEach(workoutRoutines) { workoutRoutine in
            RoutineMenuRow(routine: workoutRoutine, allPlans: allPlans, nested: true, onStart: onStart, onEdit: onEdit, onShare: onShare)
                .listRowInsets(EdgeInsets(top: 3, leading: Theme.Spacing.m, bottom: 3, trailing: Theme.Spacing.m))
                .listRowSeparator(.hidden)
        }
    }
}

/// A routine row whose tap opens a menu (start, edit, duplicate, move) anchored to the row, rather
/// than a sheet from the bottom. Shared by the plan sections and the standalone routines section.
private struct RoutineMenuRow: View {
    @EnvironmentObject var exerciseStore: ExerciseStore
    @Environment(\.managedObjectContext) var managedObjectContext

    @ObservedObject var routine: WorkoutRoutine
    var allPlans: [WorkoutPlan]
    /// When the routine belongs to a plan, it is indented with a left rail so the nesting is clear.
    var nested: Bool = false
    var onStart: (WorkoutRoutine) -> Void
    var onEdit: (WorkoutRoutine) -> Void
    var onShare: (WorkoutRoutine) -> Void

    @State private var confirmingDelete = false

    var body: some View {
        Menu {
            Button { onStart(routine) } label: { Label("Start", systemImage: "play.fill") }
            Button { onEdit(routine) } label: { Label("Edit", systemImage: "pencil") }
            Button { duplicate() } label: { Label("Duplicate", systemImage: "doc.on.doc") }
            Button { onShare(routine) } label: { Label("Share as file", systemImage: "doc.badge.arrow.up") }
            Menu {
                if routine.workoutPlan != nil {
                    Button { move(to: nil) } label: { Label("No plan", systemImage: "tray") }
                }
                ForEach(allPlans.filter { $0 != routine.workoutPlan }) { plan in
                    Button(plan.displayTitle) { move(to: plan) }
                }
            } label: { Label("Move to plan", systemImage: "folder") }
            Button(role: .destructive) {
                // Confirm only when there is something to lose; an empty routine deletes immediately.
                if (routine.workoutRoutineExercises?.count ?? 0) == 0 { delete() } else { confirmingDelete = true }
            } label: { Label("Delete", systemImage: "trash") }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(routine.displayTitle).italic()
                Text(routine.subtitle(in: exerciseStore.exercises))
                    .lineLimit(1)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // In a plan, each routine is a recessed dark well inside the plan card (no outline), so the
            // nesting reads softly instead of as outlined boxes.
            .padding(nested ? Theme.Spacing.m : 0)
            .background {
                if nested {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.forgeBackground)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
        .alert("Delete routine?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This can't be undone.")
        }
    }

    private func delete() {
        Haptics.warning()
        managedObjectContext.delete(routine)
        managedObjectContext.saveOrCrash()
    }

    private func duplicate() {
        Haptics.selection()
        let copy = routine.duplicate(context: managedObjectContext)
        copy.workoutPlan = routine.workoutPlan // same plan, or nil for a standalone routine
        managedObjectContext.saveOrCrash()
    }

    private func move(to plan: WorkoutPlan?) {
        Haptics.selection()
        // Setting the plan updates both sides of the relationship; nil makes the routine standalone.
        routine.workoutPlan = plan
        managedObjectContext.saveOrCrash()
    }
}

#if DEBUG
struct StartWorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StartWorkoutView()
            
            StartWorkoutView()
                .environment(\.colorScheme, .dark)
            
            StartWorkoutView()
                .previewDevice(.init("iPhone SE"))
            
            StartWorkoutView()
                .previewDevice(.init("iPhone 11 Pro Max"))
        }
        .mockEnvironment(weightUnit: .metric)
    }
}
#endif
