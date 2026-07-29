//
//  WarmupCalculator.swift
//  Forge
//

import Foundation

/// One warm-up set in a computed ramp. Weight is in kilograms, like `WorkoutSet.weight`.
struct WarmupSetPlan: Identifiable {
    let id = UUID()
    let weightKg: Double
    let reps: Int
}

/// Builds a warm-up ramp from a working weight. The fractions and reps are a light, familiar ramp with
/// the top set just under the working weight. Weights round to the bar's plate increment in the display
/// unit so they land on real plate loads, and no set drops below the empty bar.
enum WarmupCalculator {
    /// (fraction of the working weight, reps) for each warm-up set, lightest first.
    static let scheme: [(fraction: Double, reps: Int)] = [
        (0.40, 5),
        (0.55, 5),
        (0.70, 3),
        (0.85, 2),
    ]

    /// Warm-up sets for a working weight given in kilograms. Empty when the working weight is not set or
    /// is so light that every step rounds onto the bar or the working weight itself.
    static func plan(workingWeightKg: Double, unit: WeightUnit) -> [WarmupSetPlan] {
        guard workingWeightKg > 0 else { return [] }

        // Round in the display unit so plates land on 2.5 kg / 5 lb steps, then store back in kilograms.
        let workingDisplay = WeightUnit.convert(weight: workingWeightKg, from: .metric, to: unit)
        let increment = unit.barbellIncrement
        let bar = unit.barbellWeight

        var plans: [WarmupSetPlan] = []
        for step in scheme {
            let raw = workingDisplay * step.fraction
            let rounded = max(bar, (raw / increment).rounded() * increment)
            // A warm-up must be lighter than the working weight to be worth adding.
            guard rounded < workingDisplay else { continue }
            let weightKg = WeightUnit.convert(weight: rounded, from: unit, to: .metric)

            // Skip a step that collapses onto the previous one (light lifts can round several onto the bar).
            if let last = plans.last, abs(last.weightKg - weightKg) < 0.0001 { continue }
            plans.append(WarmupSetPlan(weightKg: weightKg, reps: step.reps))
        }
        return plans
    }
}
