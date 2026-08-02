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
        // Deliver the objectWillChange fan-out on a later runloop turn rather than synchronously inside the
        // Core Data change notification, which can fire while SwiftUI is evaluating a body ("publishing
        // changes from within view updates"). RunLoop.main (not DispatchQueue.main) defers it out of
        // event-tracking mode too, so a change that fans objectWillChange across the whole plan/routine or
        // workout subtree does not land mid-scroll or mid-touch and stall input. Views refresh a runloop
        // later; they just won't update while a scroll is actively tracking, which these editors don't need.
        workoutDataStorage.persistentContainer.viewContext.publisher
            .receive(on: RunLoop.main)
            .sink { changes in
                // Bracketed so a freeze log says whether the main thread died inside this fan-out. A
                // trail ending on "begin" with no "end" means it never came back out.
                HangMonitor.note("core data fan-out begin")
                WorkoutDataStorage.sendObjectsWillChange(changes: changes)
                HangMonitor.note("core data fan-out end")
            }
            .store(in: &cancellables)

        return workoutDataStorage
    }()
}
