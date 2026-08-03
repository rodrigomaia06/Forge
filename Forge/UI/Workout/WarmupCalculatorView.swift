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

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.forgeHeadline)
            .foregroundColor(.forgeSecondaryLabel)
            .padding(.horizontal, Theme.Layout.insetGroupedRowInset)
    }

    private var workingSetCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Weight")
                Spacer()
                RightAlignedNumberField(text: $workingWeightInput, placeholder: "0", keyboardType: .decimalPad, alignment: .right, smallPlaceholder: false)
                    .frame(width: 90, height: 28)
                Text(weightUnit.unit.symbol)
                    .foregroundColor(.forgeSecondaryLabel)
            }
            .padding(.horizontal, Theme.Layout.insetGroupedRowInset)
            .frame(minHeight: Theme.Layout.minTapTarget)
            ForgeListSeparator().padding(.horizontal, Theme.Layout.insetGroupedRowInset)
            HStack {
                Text("Reps")
                Spacer()
                RightAlignedNumberField(text: $workingRepsInput, placeholder: "0", keyboardType: .numberPad, alignment: .right, smallPlaceholder: false)
                    .frame(width: 90, height: 28)
            }
            .padding(.horizontal, Theme.Layout.insetGroupedRowInset)
            .frame(minHeight: Theme.Layout.minTapTarget)
        }
        .forgeCard()
    }

    private var warmupSetsCard: some View {
        VStack(spacing: 0) {
            if plan.isEmpty {
                Text(workingWeightKg > 0
                     ? "This weight is light enough that warm-up sets aren't needed."
                     : "Enter a working weight to see warm-up sets.")
                    .foregroundColor(.forgeSecondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Layout.insetGroupedRowInset)
                    .frame(minHeight: Theme.Layout.minTapTarget)
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
                    .padding(.horizontal, Theme.Layout.insetGroupedRowInset)
                    .frame(minHeight: Theme.Layout.minTapTarget)
                    .overlay(alignment: .bottom) {
                        if index < plan.count - 1 {
                            ForgeListSeparator().padding(.horizontal, Theme.Layout.insetGroupedRowInset)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .forgeCard()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                sectionTitle("Working set")
                workingSetCard
                sectionTitle("Warm-up sets")
                    .padding(.top, Theme.Spacing.l)
                warmupSetsCard
            }
            .padding(.horizontal, Theme.Layout.insetGroupedRowInset)
            .padding(.top, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color.forgeBackground.ignoresSafeArea())
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
