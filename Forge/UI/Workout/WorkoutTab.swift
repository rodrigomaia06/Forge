//
//  WorkoutTab.swift
//  Iron
//
//  Created by Karim Abou Zeid on 11.09.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import WorkoutDataKit

struct WorkoutTab: View {
    @FetchRequest(fetchRequest: Workout.currentWorkoutFetchRequest) var currentWorkouts
    
    private var currentWorkout: Workout? {
        assert(currentWorkouts.count <= 1)
        return currentWorkouts.first
    }
    
    var body: some View {
        ZStack { // ZStack is needed because of a bug where the TabView switches to another Tab (iOS 14.0)
            if let workout = currentWorkout {
                CurrentWorkoutView(workout: workout)
                    // Slides up over the start screen when a workout begins, so starting a routine
                    // reads as a transition rather than an instant swap.
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                StartWorkoutView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth, value: currentWorkout != nil)
    }
}

#if DEBUG
struct WorkoutTab_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutTab()
            .mockEnvironment(weightUnit: .metric)
    }
}
#endif
