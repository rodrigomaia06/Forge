//
//  CreateCustomExerciseSheet.swift
//  Iron
//
//  Created by Karim Abou Zeid on 23.09.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import WorkoutDataKit

struct CreateCustomExerciseSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var exerciseStore: ExerciseStore
    @State private var exerciseValues = EditCustomExerciseView.ExerciseValues(title: "", description: "", muscles: Set(), type: .other)
    
    private var canSave: Bool {
        let title = exerciseValues.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        guard !exerciseStore.exercises.contains(where: { $0.title == title }) else { return false }
        guard !exerciseValues.muscles.isEmpty else { return false }
        return true
    }
    
    private var saveButton: some View {
        Button("Save") {
            let title = self.exerciseValues.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = self.exerciseValues.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let primaryMuscle = self.exerciseValues.muscles
                .map { $0 }
                .filter { $0.type == .primary }
                .sorted { $0.shortDisplayTitle < $1.shortDisplayTitle }
                .map { $0.muscle }
            let secondaryMuscle = self.exerciseValues.muscles
                .map { $0 }
                .filter { $0.type == .secondary }
                .sorted { $0.shortDisplayTitle < $1.shortDisplayTitle }
                .map { $0.muscle }
            self.exerciseStore.createCustomExercise(title: title, description: description.isEmpty ? nil : description, primaryMuscle: primaryMuscle, secondaryMuscle: secondaryMuscle, type: self.exerciseValues.type)
            if let restTime = self.exerciseValues.restTime,
               let created = self.exerciseStore.customExercises.first(where: { $0.title == title }) {
                self.exerciseStore.setRestTime(restTime, forExercise: created.uuid)
            }
            self.presentationMode.wrappedValue.dismiss()
            // A success cue that the exercise was created.
            Haptics.success()
        }.disabled(!canSave)
    }
    
    var body: some View {
        NavigationStack {
            EditCustomExerciseView(exerciseValues: $exerciseValues)
                .navigationBarTitle("New exercise", displayMode: .inline)
                .navigationBarItems(
                    leading:
                    Button("Cancel") {
                        self.presentationMode.wrappedValue.dismiss()
                    },
                    trailing: saveButton
                )
        }
    }
}
