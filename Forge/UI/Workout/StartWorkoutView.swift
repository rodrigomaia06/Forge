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

    // Tapping a routine opens a menu (start, edit, duplicate, move) anchored to the row.
    @State private var routineToEdit: WorkoutRoutine?
    
    @FetchRequest(fetchRequest: StartWorkoutView.fetchRequest) var workoutPlans

    static var fetchRequest: NSFetchRequest<WorkoutPlan> {
        let request: NSFetchRequest<WorkoutPlan> = WorkoutPlan.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WorkoutPlan.title, ascending: false)]
        return request
    }
    
    // Start a workout, or create a plan. The plus is the single entry point (no separate button).
    private var addMenu: some View {
        Menu {
            Button {
                Haptics.impact(.medium)
                Workout.create(context: self.managedObjectContext).startOrCrash()
            } label: {
                Label("New workout", systemImage: "figure.strengthtraining.traditional")
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
                    ForEach(workoutPlans) { workoutPlan in
                        Section {
                            WorkoutPlanCell(workoutPlan: workoutPlan)
                            WorkoutPlanRoutines(workoutPlan: workoutPlan, allPlans: Array(workoutPlans), onStart: { start(routine: $0) }, onEdit: { routineToEdit = $0 })
                                .deleteDisabled(true)
                        }
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
            .confirmationDialog("This cannot be undone.", isPresented: Binding(get: { offsetsToDelete != nil }, set: { if !$0 { offsetsToDelete = nil } }), titleVisibility: .visible, presenting: offsetsToDelete) { offsets in
                Button("Delete workout plan", role: .destructive) {
                    self.deleteAt(offsets: offsets)
                }
            }
        }
    }

    /// Start a workout from a routine. Animated so the live workout slides in rather than snapping.
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
            VStack(alignment: .leading) {
                Text(workoutPlan.displayTitle).font(.headline)
            }
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
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    
    @Environment(\.managedObjectContext) var managedObjectContext
    
    @ObservedObject var workoutPlan: WorkoutPlan

    /// All plans, so a routine can be moved to another one.
    var allPlans: [WorkoutPlan]
    var onStart: (WorkoutRoutine) -> Void
    var onEdit: (WorkoutRoutine) -> Void

    private var workoutRoutines: [WorkoutRoutine] {
        workoutPlan.workoutRoutines?.array as? [WorkoutRoutine] ?? []
    }

    var body: some View {
        ForEach(workoutRoutines) { workoutRoutine in
            // A menu anchored to the row, so the choices appear next to the routine rather than as a
            // sheet from the bottom of the screen.
            Menu {
                Button { onStart(workoutRoutine) } label: { Label("Start", systemImage: "play.fill") }
                Button { onEdit(workoutRoutine) } label: { Label("Edit", systemImage: "pencil") }
                Button { duplicate(workoutRoutine) } label: { Label("Duplicate", systemImage: "doc.on.doc") }
                let otherPlans = allPlans.filter { $0 != workoutPlan }
                if !otherPlans.isEmpty {
                    Menu {
                        ForEach(otherPlans) { plan in
                            Button(plan.displayTitle) { move(workoutRoutine, to: plan) }
                        }
                    } label: { Label("Move to plan", systemImage: "folder") }
                }
            } label: {
                VStack(alignment: .leading) {
                    Text(workoutRoutine.displayTitle).italic()
                    Text(workoutRoutine.subtitle(in: self.exerciseStore.exercises))
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundColor(.primary)
        }
    }

    private func duplicate(_ routine: WorkoutRoutine) {
        Haptics.selection()
        let copy = routine.duplicate(context: managedObjectContext)
        workoutPlan.addToWorkoutRoutines(copy)
        managedObjectContext.saveOrCrash()
    }

    private func move(_ routine: WorkoutRoutine, to plan: WorkoutPlan) {
        Haptics.selection()
        // Setting the plan updates both sides of the relationship, moving the routine out of this plan.
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
