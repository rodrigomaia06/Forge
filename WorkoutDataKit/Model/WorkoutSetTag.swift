//
//  WorkoutSetTag.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 22.08.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import Foundation

public enum WorkoutSetTag: String, CaseIterable {
    case warmUp
    case dropSet
    case failure
    case backOff

    public var title: String {
        switch self {
        case .warmUp:
            return "warm up"
        case .dropSet:
            return "drop set"
        case .failure:
            return "failure"
        case .backOff:
            return "back-off"
        }
    }
}
