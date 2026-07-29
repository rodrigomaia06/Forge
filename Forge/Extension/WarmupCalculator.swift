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

/// Builds a warm-up ramp from a working weight and its reps. It is a reference only: the app shows the
/// ramp, it does not add sets. Weights round to the bar's plate increment in the display unit so they
/// land on real plate loads and never drop below the empty bar. Reps are a fraction of the working reps,
/// so a heavy low-rep day warms up with fewer reps than a lighter high-rep day.
enum WarmupCalculator {
    /// (fraction of working weight, fraction of working reps) per warm-up set, lightest first.
    static let scheme: [(weightFraction: Double, repFraction: Double)] = [
        (0.40, 0.8),
        (0.55, 0.6),
        (0.70, 0.4),
        (0.85, 0.2),
    ]

    /// Warm-up sets for a working weight (kilograms) and working reps. Empty when the working weight is
    /// not set or is so light that every step rounds onto the bar or the working weight itself.
    static func plan(workingWeightKg: Double, workingReps: Int, unit: WeightUnit) -> [WarmupSetPlan] {
        guard workingWeightKg > 0 else { return [] }

        // Round in the display unit so plates land on 2.5 kg / 5 lb steps, then store back in kilograms.
        let workingDisplay = WeightUnit.convert(weight: workingWeightKg, from: .metric, to: unit)
        let increment = unit.barbellIncrement
        let bar = unit.barbellWeight
        // Reps only scale down from a real working-rep count; without one, fall back to a fixed light ramp.
        let baseReps = workingReps > 0 ? Double(workingReps) : 5

        var plans: [WarmupSetPlan] = []
        for step in scheme {
            let raw = workingDisplay * step.weightFraction
            let rounded = max(bar, (raw / increment).rounded() * increment)
            // A warm-up must be lighter than the working weight to be worth showing.
            guard rounded < workingDisplay else { continue }
            let weightKg = WeightUnit.convert(weight: rounded, from: unit, to: .metric)
            let reps = max(1, Int((baseReps * step.repFraction).rounded()))

            // Skip a step that collapses onto the previous one (light lifts can round several onto the bar).
            if let last = plans.last, abs(last.weightKg - weightKg) < 0.0001 { continue }
            plans.append(WarmupSetPlan(weightKg: weightKg, reps: reps))
        }
        return plans
    }
}
