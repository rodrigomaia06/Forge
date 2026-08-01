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
        // Deliver the objectWillChange fan-out on the next main-queue tick rather than synchronously inside
        // the Core Data change notification. That notification can fire while SwiftUI is evaluating a body
        // (a @FetchRequest read forces processPendingChanges), so sending objectWillChange to the objects
        // being rendered right then is "publishing changes from within view updates", which can wedge the
        // update graph into a hard freeze while timers keep ticking. Deferring one tick breaks that
        // reentrancy; views still refresh, a runloop later. DispatchQueue.main (not RunLoop.main) so it
        // also delivers during scroll tracking.
        workoutDataStorage.persistentContainer.viewContext.publisher
            .receive(on: DispatchQueue.main)
            .sink { changes in
                WorkoutDataStorage.sendObjectsWillChange(changes: changes)
            }
            .store(in: &cancellables)

        return workoutDataStorage
    }()
}
