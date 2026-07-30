//
//  WarmupCalculatorView.swift
//  Forge
//

import SwiftUI
import WorkoutDataKit

/// Shows a warm-up ramp for a working weight and reps. You can just read it, or add the sets to the
/// exercise. The ramp is computed by `WarmupCalculator`; the caller inserts the sets when Add is tapped.
struct WarmupCalculatorView: View {
    @Environment(\.dismiss) private var dismiss

    let weightUnit: WeightUnit
    /// Working weight to base the ramp on, in kilograms. Zero shows an empty field to type into.
    let initialWorkingWeightKg: Double
    /// Working reps to base the ramp on. Zero falls back to a light default rep ramp.
    let initialWorkingReps: Int
    /// Called with the computed warm-up sets (lightest first) when Add is tapped.
    let onAdd: ([WarmupSetPlan]) -> Void

    @State private var workingWeightInput = ""
    @State private var workingRepsInput = ""

    /// Sheet height grows with the number of warm-up rows so a long ramp is not clipped and a short one
    /// is not surrounded by empty space. The drag handle still expands it to full height.
    private var sheetHeight: CGFloat {
        let rows = max(plan.count, 1)
        return 320 + CGFloat(rows) * 52
    }

    private var workingWeightKg: Double {
        let normalized = workingWeightInput.replacingOccurrences(of: ",", with: ".")
        let display = Double(normalized) ?? 0
        return WeightUnit.convert(weight: display, from: weightUnit, to: .metric)
    }

    private var workingReps: Int { Int(workingRepsInput) ?? 0 }

    private var plan: [WarmupSetPlan] {
        WarmupCalculator.plan(workingWeightKg: workingWeightKg, workingReps: workingReps, unit: weightUnit)
    }

    private func weightText(_ kg: Double) -> String {
        weightUnit.numberFormatter.string(from: WeightUnit.convert(weight: kg, from: .metric, to: weightUnit) as NSNumber) ?? ""
    }

    var body: some View {
        Form {
            Section(header: Text("Working set")) {
                HStack {
                    Text("Weight")
                    Spacer()
                    RightAlignedNumberField(text: $workingWeightInput, placeholder: "0", keyboardType: .decimalPad, alignment: .right)
                        .frame(width: 90, height: 28)
                    Text(weightUnit.unit.symbol)
                        .foregroundColor(.forgeSecondaryLabel)
                }
                HStack {
                    Text("Reps")
                    Spacer()
                    RightAlignedNumberField(text: $workingRepsInput, placeholder: "0", keyboardType: .numberPad, alignment: .right)
                        .frame(width: 90, height: 28)
                }
            }

            Section(header: Text("Warm-up sets")) {
                if plan.isEmpty {
                    Text(workingWeightKg > 0
                         ? "This weight is light enough that warm-up sets aren't needed."
                         : "Enter a working weight to see warm-up sets.")
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
        .presentationDetents([.height(sheetHeight), .large])
        .presentationDragIndicator(.visible)
        .navigationBarTitle("Warm-up sets", displayMode: .inline)
        .navigationBarItems(
            leading: Button("Done") { dismiss() },
            trailing: Button("Add sets") {
                onAdd(plan)
                dismiss()
            }
            .fontWeight(.semibold)
            .disabled(plan.isEmpty)
        )
        .onAppear {
            if workingWeightInput.isEmpty, initialWorkingWeightKg > 0 {
                workingWeightInput = weightText(initialWorkingWeightKg)
            }
            if workingRepsInput.isEmpty, initialWorkingReps > 0 {
                workingRepsInput = String(initialWorkingReps)
            }
        }
    }
}
