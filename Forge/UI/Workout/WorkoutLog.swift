//
//  WorkoutLog.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 12.08.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import WorkoutDataKit

struct WorkoutLog: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    
    @ObservedObject var workout: Workout
    
    private func workoutSets(workoutExercise: WorkoutExercise) -> [WorkoutSet] {
        workoutExercise.workoutSets?
            .compactMap { $0 as? WorkoutSet }
            .filter { $0.isCompleted } ?? []
    }
    
    private func workoutExerciseView(workoutExercise: WorkoutExercise) -> some View {
        VStack(alignment: .leading) {
            Text(workoutExercise.exercise(in: self.exerciseStore.exercises)?.title ?? "")
                .font(.body)
            workoutExercise.comment.map {
                Text($0.enquoted)
                    .lineLimit(1)
                    .font(Font.caption.italic())
                    .foregroundColor(.secondary)
            }
            ForEach(self.workoutSets(workoutExercise: workoutExercise)) { workoutSet in
                Text(workoutSet.logTitle(weightUnit: self.settingsStore.weightUnit))
                    .font(Font.body.monospacedDigit())
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
        }
    }
    
    var body: some View {
        List {
            Section {
                WorkoutLogBannerView(workout: workout)
                    .padding([.top, .bottom])
                    .frame(maxWidth: .infinity)
                    // Match the workout detail: stats on the normal surface with a thin muscle-group rule.
                    .overlay(alignment: .bottom) {
                        Capsule()
                            .fill(workout.muscleGroupColor(in: exerciseStore.exercises))
                            .frame(height: 3)
                            .padding(.horizontal, Theme.Spacing.m)
                    }
            }
            Section {
                ForEach(workout.workoutExercisesWhereNotAllSetsAreUncompleted ?? []) {
                    self.workoutExerciseView(workoutExercise: $0)
                }
            }
        }
        .listStyleCompat_InsetGroupedListStyle()
    }
}

private struct WorkoutLogBannerView : View {
    @EnvironmentObject var settingsStore: SettingsStore
    @ObservedObject var workout: Workout
    
    var body: some View {
        BannerView(entries: bannerViewEntries)
    }
    
    private var bannerViewEntries: [BannerViewEntry] {
        var entries = [BannerViewEntry]()
        
        entries.append(BannerViewEntry(id: 0, title: Text("Sets"), text: Text(String(workout.numberOfCompletedSets ?? 0))))
        entries.append(BannerViewEntry(id: 1, title: Text("Weight"), text: Text("\(WeightUnit.format(weight: workout.totalCompletedWeight ?? 0, from: .metric, to: settingsStore.weightUnit))")))
        return entries
    }
}

#if DEBUG
struct WorkoutLog_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutLog(workout: MockWorkoutData.metricRandom.currentWorkout)
            .mockEnvironment(weightUnit: .metric)
    }
}
#endif
