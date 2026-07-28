//
//  WorkoutDataStorage+shared.swift
//  Iron
//
//  Created by Karim Abou Zeid on 05.12.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import Foundation
import WorkoutDataKit
import CoreData
import Combine
import WidgetKit
import os.log

extension WorkoutDataStorage {
    private static var cancellables = Set<AnyCancellable>()
    
    private static var workoutsChangedSubject = PassthroughSubject<Void, Never>()

    static let shared: WorkoutDataStorage = {
        let workoutDataStorage = WorkoutDataStorage(storeDescription: .init(url: groupStoreURL))
        workoutDataStorage.persistentContainer.viewContext.publisher
            .sink { changes in
                WorkoutDataStorage.sendObjectsWillChange(changes: changes)
            }
            .store(in: &cancellables)
        
        if #available(iOS 14.0, *) {
            workoutDataStorage.persistentContainer.viewContext.publisher
                .sink { changes in
                    if changes.inserted.union(changes.deleted).contains(where: { $0 is Workout }) {
                        workoutsChangedSubject.send()
                    } else {
                        let hasUpdatedWorkout = changes.updated.contains {
                            guard let workout = $0 as? Workout else { return false }
                            guard !workout.isFault else { return false }
                            guard !workout.isCurrentWorkout else { return false }
                            return true
                        }
                        if hasUpdatedWorkout {
                            workoutsChangedSubject.send()
                        }
                    }
                }
                .store(in: &cancellables)
            
            workoutsChangedSubject
                .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
                .sink(receiveValue: WidgetKind.lastWorkout.reloadTimelines)
                .store(in: &cancellables)
        }
        
        return workoutDataStorage
    }()
}
