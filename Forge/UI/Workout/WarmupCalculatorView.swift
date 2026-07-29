//
//  WarmupCalculatorView.swift
//  Forge
//

import SwiftUI
import WorkoutDataKit

/// Enter a working weight and add a warm-up ramp of sets before the working sets. The ramp is computed
/// by `WarmupCalculator`; the caller inserts the returned sets.
struct WarmupCalculatorView: View {
    @Environment(\.dismiss) private var dismiss

    let weightUnit: WeightUnit
    /// Working weight to base the ramp on, in kilograms. Zero shows an empty field to type into.
    let initialWorkingWeightKg: Double
    /// Called with the computed warm-up sets (lightest first) when Add is tapped.
    let onAdd: ([WarmupSetPlan]) -> Void

    @State private var workingWeightInput = ""

    private var workingWeightKg: Double {
        let normalized = workingWeightInput.replacingOccurrences(of: ",", with: ".")
        let display = Double(normalized) ?? 0
        return WeightUnit.convert(weight: display, from: weightUnit, to: .metric)
    }

    private var plan: [WarmupSetPlan] {
        WarmupCalculator.plan(workingWeightKg: workingWeightKg, unit: weightUnit)
    }

    private func weightText(_ kg: Double) -> String {
        weightUnit.numberFormatter.string(from: WeightUnit.convert(weight: kg, from: .metric, to: weightUnit) as NSNumber) ?? ""
    }

    var body: some View {
        Form {
            Section(header: Text("Working weight")) {
                HStack {
                    TextField("0", text: $workingWeightInput)
                        .keyboardType(.decimalPad)
                    Text(weightUnit.unit.symbol)
                        .foregroundColor(.forgeSecondaryLabel)
                }
            }

            Section(header: Text("Warm-up sets")) {
                if plan.isEmpty {
                    Text("Enter a working weight to see warm-up sets.")
                        .foregroundColor(.forgeSecondaryLabel)
                } else {
                    ForEach(Array(plan.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text("\(index + 1)")
                                .foregroundColor(.forgeSecondaryLabel)
                                .frame(width: 24, alignment: .leading)
                            Text("\(weightText(set.weightKg)) \(weightUnit.unit.symbol)")
                                .font(.body.monospacedDigit())
                            Spacer()
                            Text("× \(set.reps)")
                                .font(.body.monospacedDigit())
                                .foregroundColor(.forgeSecondaryLabel)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .keyboardDoneToolbar()
        .navigationBarTitle("Warm-up sets", displayMode: .inline)
        .navigationBarItems(
            leading: Button("Cancel") { dismiss() },
            trailing: Button("Add") {
                onAdd(plan)
                dismiss()
            }
            .disabled(plan.isEmpty)
        )
        .onAppear {
            guard workingWeightInput.isEmpty, initialWorkingWeightKg > 0 else { return }
            workingWeightInput = weightText(initialWorkingWeightKg)
        }
    }
}
