//
//  ExerciseStore+shared.swift
//  Iron
//
//  Created by Karim Abou Zeid on 06.12.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import Foundation
import WorkoutDataKit

extension ExerciseStore {
    // Custom exercises and per-exercise settings live in the workout database, so the store
    // reads and writes them through the shared Core Data context.
    static let shared = ExerciseStore(
        context: WorkoutDataStorage.shared.persistentContainer.viewContext
    )
}
