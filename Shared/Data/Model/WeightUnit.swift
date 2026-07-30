//
//  WeightUnit.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 16.07.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import Foundation

enum WeightUnit: String, CaseIterable, Hashable {
    case metric
    case imperial
    
    var title: String {
        switch self {
        case .metric:
            return "Metric (kg)"
        case .imperial:
            return "Imperial (lb)"
        }
    }
    
    var unit: UnitMass {
        switch self {
        case .metric:
            return .kilograms
        case .imperial:
            return .pounds
        }
    }
}

extension WeightUnit {
    var minimumFractionDigits: Int { 0 }
    var maximumFractionDigits: Int { 3 }
    var defaultFractionDigits: Int {
        switch self {
        case .metric:
            return 1
        case .imperial:
            return 0
        }
    }
    
    // The number and measurement formatters are the same for both units (the unit is supplied by the
    // Measurement being formatted), so share one instance instead of allocating a new MeasurementFormatter
    // on every access. Building a MeasurementFormatter is expensive and this is read once per set row.
    private static let sharedNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.allowsFloats = true
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        return formatter
    }()

    private static let sharedMeasurementFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter = sharedNumberFormatter
        return formatter
    }()

    var numberFormatter: NumberFormatter { Self.sharedNumberFormatter }

    var formatter: MeasurementFormatter { Self.sharedMeasurementFormatter }
}

extension WeightUnit {
    static func convert(weight: Double, from: WeightUnit, to: WeightUnit) -> Double {
        Measurement(value: weight, unit: from.unit).converted(to: to.unit).value
    }
    
    static func format(weight: Double, from: WeightUnit, to: WeightUnit) -> String {
        to.formatter.string(from: Measurement(value: weight, unit: from.unit).converted(to: to.unit))
    }
}

extension WeightUnit {
    var barbellIncrement: Double {
        switch self {
        case .metric:
            return 2.5 // 2x 1.25 kg
        case .imperial:
            return 5 // 2x 2.5 lb
        }
    }
    
    var barbellWeight: Double {
        switch self {
        case .metric:
            return 20
        case .imperial:
            return 45
        }
    }
}
