//
//  AddExercisesSheet.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 03.09.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import WorkoutDataKit
import CoreData

struct AddExercisesSheet: View {
    @Environment(\.presentationMode) var presentationMode

    let onAdd: (Set<Exercise>) -> Void
    /// When provided, the sheet offers "Add as superset" once two or more exercises are selected, and
    /// hands them back in the order they appear in the list. Nil at call sites where a superset does not
    /// apply (editing a routine or a past workout), so those keep only the plain Add.
    let onAddSuperset: (([Exercise]) -> Void)?

    private let allExercises: [Exercise]
    private let recentExercises: [Exercise]

    @State private var exerciseSelectorSelection: Set<Exercise> = Set()
    @State private var search = ""
    @State private var equipment: String? = nil
    @State private var bodyPart: String? = nil

    init(exercises: [Exercise], recentExercises: [Exercise], onAdd: @escaping (Set<Exercise>) -> Void, onAddSuperset: (([Exercise]) -> Void)? = nil) {
        self.allExercises = exercises
        self.recentExercises = recentExercises
        self.onAdd = onAdd
        self.onAddSuperset = onAddSuperset
    }

    /// The current selection in the order the exercises appear in the list (Recent counts once), so a
    /// superset is created in a sensible, stable order that the user can still change later in Edit.
    private var orderedSelection: [Exercise] {
        var seen = Set<Exercise>()
        var ordered: [Exercise] = []
        for exercise in exerciseGroups.flatMap({ $0.exercises }) where exerciseSelectorSelection.contains(exercise) {
            if seen.insert(exercise).inserted { ordered.append(exercise) }
        }
        return ordered
    }

    // Equipment filters, shown as a submenu. The token is matched against each exercise's equipment.
    private static let equipmentFilters: [(label: String, token: String)] = [
        ("Barbell", "barbell"), ("Dumbbell", "dumbbell"), ("Cable", "cable"),
        ("Machine", "machine"), ("Kettlebell", "kettlebell"), ("Bodyweight", "body"),
    ]

    private var bodyPartOptions: [String] {
        Array(Set(allExercises.map { $0.muscleGroup })).sorted()
    }

    private var filtersActive: Bool { equipment != nil || bodyPart != nil }

    private var exerciseGroups: [ExerciseGroup] {
        var exercises = allExercises
        if let equipment { exercises = exercises.filter { $0.equipment.contains { $0.contains(equipment) } } }
        if let bodyPart { exercises = exercises.filter { $0.muscleGroup == bodyPart } }
        if !search.isEmpty { exercises = ExerciseStore.filter(exercises: exercises, using: search) }
        // Selected exercises live only in the Selected section, so they are not duplicated in the lists
        // below when picked from Recent or a muscle group.
        let unselected = exercises.filter { !exerciseSelectorSelection.contains($0) }
        var groups = ExerciseStore.splitIntoMuscleGroups(exercises: unselected)
        // Recent is only meaningful with no search or filters applied.
        if search.isEmpty, !filtersActive {
            let recent = recentExercises.filter { !exerciseSelectorSelection.contains($0) }
            if !recent.isEmpty {
                groups = [ExerciseGroup(title: "Recent", exercises: recent)] + groups
            }
        }
        // Selected first, so what you have picked stays visible at the top, even while searching.
        if !exerciseSelectorSelection.isEmpty {
            let selected = allExercises.filter { exerciseSelectorSelection.contains($0) }
            groups = [ExerciseGroup(title: "Selected", exercises: selected)] + groups
        }
        return groups
    }

    private func resetAndDismiss() {
        self.presentationMode.wrappedValue.dismiss()
        self.exerciseSelectorSelection.removeAll()
        self.search = ""
    }
    
    static func loadRecentExercises(context: NSManagedObjectContext, exercises: [Exercise], maxCount: Int = 7) -> [Exercise] {
        guard maxCount > 0 else { return [] }
        let request: NSFetchRequest<Workout> = Workout.fetchRequest()
        request.predicate = NSPredicate(format: "\(#keyPath(Workout.isCurrentWorkout)) != %@", NSNumber(booleanLiteral: true))
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Workout.start, ascending: false)]
        guard let workouts = try? context.fetch(request) else { return [] }
        var recentExercises = [Exercise]()
        for workout in workouts {
            if let workoutExercises = workout.workoutExercises?.array as? [WorkoutExercise] {
                for workoutExercise in workoutExercises {
                    if let exercise = workoutExercise.exercise(in: exercises) {
                        if !recentExercises.contains(exercise) {
                            recentExercises.append(exercise)
                            if recentExercises.count >= maxCount {
                                return recentExercises
                            }
                        }
                    }
                }
            }
        }
        return recentExercises
    }
    
    var body: some View {
        NavigationStack {
            ExerciseMultiSelectionView(exerciseGroups: exerciseGroups, selection: self.$exerciseSelectorSelection)
                .navigationTitle("Add exercises")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { self.resetAndDismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) { filterMenu }
                }
                // Add lives in a bottom bar, not the nav bar, so focusing the search field cannot hide it.
                .safeAreaInset(edge: .bottom) {
                    if !exerciseSelectorSelection.isEmpty {
                        addBar
                    }
                }
        }
    }

    private var addBar: some View {
        HStack(spacing: Theme.Spacing.m) {
            Text("\(exerciseSelectorSelection.count) selected")
                .font(.forgeCaption)
                .foregroundColor(.forgeSecondaryLabel)
            Spacer()
            if onAddSuperset != nil, exerciseSelectorSelection.count >= 2 {
                Button("Add as superset") {
                    onAddSuperset?(orderedSelection)
                    resetAndDismiss()
                }
                .font(.forgeHeadline)
                .foregroundColor(.forgeAccent)
            }
            Button {
                onAdd(exerciseSelectorSelection)
                resetAndDismiss()
            } label: {
                Text("Add")
                    .font(.forgeHeadline)
                    .foregroundColor(.forgeBackground)
                    .padding(.horizontal, Theme.Spacing.l)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(Color.forgeAccent))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(.bar)
    }

    private var filterMenu: some View {
        Menu {
            Picker("Equipment", selection: $equipment) {
                Text("Any equipment").tag(String?.none)
                ForEach(Self.equipmentFilters, id: \.token) { filter in
                    Text(filter.label).tag(String?.some(filter.token))
                }
            }
            Picker("Body part", selection: $bodyPart) {
                Text("Any body part").tag(String?.none)
                ForEach(bodyPartOptions, id: \.self) { part in
                    Text(part.capitalized).tag(String?.some(part))
                }
            }
            if filtersActive {
                Button(role: .destructive) { equipment = nil; bodyPart = nil } label: {
                    Label("Clear filters", systemImage: "xmark.circle")
                }
            }
        } label: {
            Image(systemName: filtersActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Filter exercises")
    }
}

struct AddExercisesSheet_Previews: PreviewProvider {
    static var previews: some View {
//        Color.clear.sheet(isPresented: .constant(true)) {
        AddExercisesSheet(
            exercises: ExerciseStore.shared.shownExercises,
            recentExercises: [],
            onAdd: { _ in }
        )
//        }
    }
}
