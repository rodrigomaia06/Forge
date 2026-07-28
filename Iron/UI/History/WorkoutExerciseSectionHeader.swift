//
//  WorkoutExerciseSectionHeader.swift
//  Iron
//
//  Created by Karim Abou Zeid on 13.10.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import WorkoutDataKit

struct WorkoutExerciseSectionHeader: View {
    @ObservedObject var workoutExercise: WorkoutExercise

    var body: some View {
        HStack {
            Text(Workout.dateFormatter.string(from: workoutExercise.workout?.start, fallback: "Unknown date"))
            Spacer()
        }
    }
}

#if DEBUG
struct WorkoutExerciseSectionHeader_Previews: PreviewProvider {
    static var previews: some View {
        List {
            Section(header: WorkoutExerciseSectionHeader(workoutExercise: MockWorkoutData.metricRandom.workoutExercise)) {
                Text("Some cell")
            }
        }
        .listStyle(GroupedListStyle())
    }
}
#endif
