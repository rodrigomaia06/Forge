//
//  Workout+WeightUnit.swift
//  Iron
//
//  Created by Karim Abou Zeid on 05.12.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import Foundation
import WorkoutDataKit

extension Workout {
    func logText(in exercises: [Exercise], weightUnit: WeightUnit, bodyweight: Double) -> String? {
        logText(in: exercises, unit: weightUnit.unit, formatter: weightUnit.formatter, bodyweight: bodyweight)
    }
}
