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

/// Builds a warm-up ramp from a working weight and its reps. It is a reference: the app shows the ramp
/// and can add the sets. The ramp's shape follows intensity, which the working reps signal: a heavy
/// low-rep set gets more ramp sets ending near the working weight with the warm-up reps dropping to
/// prime the nervous system, while a lighter high-rep set gets a short ramp with higher rehearsal reps.
/// Weights round to the bar's plate increment in the display unit and never drop below the empty bar.
///
/// The percentages and rep counts follow common strength-training guidance (progressive ~40/55/70/85%
/// with reps decreasing as the weight rises, a top warm-up around 75-85%, and fewer sets for lighter,
/// higher-rep work).
enum WarmupCalculator {
    struct Step {
        let weightFraction: Double
        let reps: Int
        init(_ weightFraction: Double, _ reps: Int) {
            self.weightFraction = weightFraction
            self.reps = reps
        }
    }

    /// Ramp steps for the working reps, lightest first. Unknown reps (0) use the moderate ramp.
    static func steps(forWorkingReps reps: Int) -> [Step] {
        if reps >= 12 {
            // Light, high-rep work: a short ramp is enough.
            return [Step(0.50, 8), Step(0.70, 5)]
        } else if reps >= 1 && reps <= 5 {
            // Heavy, low-rep work: more sets, ending close to the working weight, low reps near the top.
            return [Step(0.40, 5), Step(0.55, 3), Step(0.70, 2), Step(0.85, 1)]
        } else {
            // Moderate work (6-11 reps), and the fallback when the reps are unknown.
            return [Step(0.40, 8), Step(0.60, 5), Step(0.80, 3)]
        }
    }

    /// Warm-up sets for a working weight (kilograms) and working reps. Empty when the working weight is
    /// not set or is so light that every step rounds onto the bar or the working weight itself.
    static func plan(workingWeightKg: Double, workingReps: Int, unit: WeightUnit) -> [WarmupSetPlan] {
        guard workingWeightKg > 0 else { return [] }

        // Round in the display unit so plates land on 2.5 kg / 5 lb steps, then store back in kilograms.
        let workingDisplay = WeightUnit.convert(weight: workingWeightKg, from: .metric, to: unit)
        let increment = unit.barbellIncrement
        let bar = unit.barbellWeight

        var plans: [WarmupSetPlan] = []
        for step in steps(forWorkingReps: workingReps) {
            let raw = workingDisplay * step.weightFraction
            let rounded = max(bar, (raw / increment).rounded() * increment)
            // A warm-up must be lighter than the working weight to be worth showing.
            guard rounded < workingDisplay else { continue }
            let weightKg = WeightUnit.convert(weight: rounded, from: unit, to: .metric)

            // Skip a step that collapses onto the previous one (light lifts can round several onto the bar).
            if let last = plans.last, abs(last.weightKg - weightKg) < 0.0001 { continue }
            plans.append(WarmupSetPlan(weightKg: weightKg, reps: step.reps))
        }
        return plans
    }
}
