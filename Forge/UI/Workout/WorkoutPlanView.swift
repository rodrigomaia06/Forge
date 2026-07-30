//
//  WorkoutPlanView.swift
//  Iron
//
//  Created by Karim Abou Zeid on 21.12.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import WorkoutDataKit
import os.log

struct WorkoutPlanView: View {
    @EnvironmentObject var exerciseStore: ExerciseStore
    @Environment(\.managedObjectContext) var managedObjectContext
    @Environment(\.editMode) private var editMode

    @ObservedObject var workoutPlan: WorkoutPlan

    @State private var offsetsToDelete: IndexSet?
    @State private var activityItems: [Any]?

    /// Write this plan to a JSON file and open the share sheet, so it can be sent to someone who can
    /// import it into their own Forge.
    private func shareAsJSON() {
        do {
            let data = try WorkoutDataExchange.export(plans: [workoutPlan])
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("workout-plan.json")
            try data.write(to: url)
            self.activityItems = [url]
        } catch {
            os_log("Could not export plan as JSON: %@", type: .error, error.localizedDescription)
        }
    }
    
    @State private var workoutPlanTitleInput: String? = nil
    private var workoutPlanTitle: Binding<String> {
        Binding(
            get: {
                self.workoutPlanTitleInput ?? self.workoutPlan.title ?? ""
            },
            set: { newValue in
                self.workoutPlanTitleInput = newValue
            }
        )
    }
    private func adjustAndSaveWorkoutTitleInput() {
        guard let newValue = workoutPlanTitleInput?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        workoutPlanTitleInput = newValue
        workoutPlan.title = newValue.isEmpty ? nil : newValue
        self.managedObjectContext.saveOrCrash()
    }
    
    private var workoutRoutines: [WorkoutRoutine] {
        workoutPlan.workoutRoutines?.array as? [WorkoutRoutine] ?? []
    }
    
    var body: some View {
        List {
            Section {
                TextField("Title", text: workoutPlanTitle, onEditingChanged: { isEditingTextField in
                    if !isEditingTextField {
                        self.adjustAndSaveWorkoutTitleInput()
                    }
                })
            }
            Section(header: Text("Routines".uppercased())) {
                ForEach(workoutRoutines) { workoutRoutine in
                    NavigationLink(destination: WorkoutRoutineView(workoutRoutine: workoutRoutine)) {
                        VStack(alignment: .leading) {
                            Text(workoutRoutine.displayTitle)
                            Text(workoutRoutine.subtitle(in: self.exerciseStore.exercises))
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .onDelete { offsets in
                    if self.needsConfirmBeforeDelete(offsets: offsets) {
                        self.offsetsToDelete = offsets
                    } else {
                        self.deleteAt(offsets: offsets)
                    }
                }
                .onMove { source, destination in
                    var workoutRoutines = self.workoutRoutines
                    workoutRoutines.move(fromOffsets: source, toOffset: destination)
                    self.workoutPlan.workoutRoutines = NSOrderedSet(array: workoutRoutines)
                    self.managedObjectContext.saveOrCrash()
                }
                // Reordering only in edit mode, so a stray long-press can't reorder the plan's routines.
                .moveDisabled(editMode?.wrappedValue.isEditing != true)
                
                Button(action: {
                    self.createWorkoutRoutine()
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add routine")
                    }
                }
            }
        }
        .listStyleCompat_InsetGroupedListStyle()
        .keyboardDoneToolbar()
        .navigationBarTitle(Text(workoutPlan.displayTitle), displayMode: .inline)
        // A ToolbarItemGroup spaces the buttons the native way, so Share and Edit are not cramped like
        // the deprecated navigationBarItems(HStack:) placed them.
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button { shareAsJSON() } label: { Label("Share as file", systemImage: "doc.badge.arrow.up") }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share plan")
                EditButton()
            }
        }
        .overlay(ActivitySheet(activityItems: $activityItems))
        .alert("Delete workout routine?", isPresented: Binding(get: { offsetsToDelete != nil }, set: { if !$0 { offsetsToDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let offsets = offsetsToDelete { self.deleteAt(offsets: offsets) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This cannot be undone.")
        }
    }
    
    private func createWorkoutRoutine() {
        let workoutRoutine = WorkoutRoutine.create(context: managedObjectContext)
        workoutRoutine.workoutPlan = workoutPlan
        managedObjectContext.saveOrCrash()
    }
    
    /// Resturns `true` if at least one workout routine has workout routine exercises
    private func needsConfirmBeforeDelete(offsets: IndexSet) -> Bool {
        for index in offsets {
            if workoutRoutines[index].workoutRoutineExercises?.count ?? 0 != 0 {
                return true
            }
        }
        return false
    }
    
    private func deleteAt(offsets: IndexSet) {
        let workoutRoutines = self.workoutRoutines
        for i in offsets {
            self.managedObjectContext.delete(workoutRoutines[i])
        }
        self.managedObjectContext.saveOrCrash()
    }
}

#if DEBUG
struct WorkoutPlanView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WorkoutPlanView(workoutPlan: MockWorkoutData.metric.workoutPlan)
                .mockEnvironment(weightUnit: .metric)
        }
    }
}
#endif
