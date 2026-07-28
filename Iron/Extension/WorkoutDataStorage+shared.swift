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
import os.log

extension WorkoutDataStorage {
    private static var cancellables = Set<AnyCancellable>()

    static let shared: WorkoutDataStorage = {
        let workoutDataStorage = WorkoutDataStorage(storeDescription: .init(url: groupStoreURL))
        workoutDataStorage.persistentContainer.viewContext.publisher
            .sink { changes in
                WorkoutDataStorage.sendObjectsWillChange(changes: changes)
            }
            .store(in: &cancellables)

        return workoutDataStorage
    }()
}
