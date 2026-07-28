//
//  WorkoutSetCell.swift
//  Forge
//
//  The set row used across every workout and history screen. Restyled on the Forge
//  design tokens (see ForgeSetRow, which is the same visual language as a standalone,
//  value-based component). All existing states are preserved: placeholder, selection,
//  completed / up-next, set tag, personal record, RPE, and the disabled (history) mode.
//

import SwiftUI
import WorkoutDataKit

struct WorkoutSetCell: View {
    @EnvironmentObject var settingsStore: SettingsStore

    @ObservedObject var workoutSet: WorkoutSet
    let index: Int
    var colorMode: ColorMode = .activated
    var isPlaceholder = false
    var showCompleted = false
    var showUpNextIndicator = false

    enum ColorMode {
        case selected
        case activated
        case deactivated
        case disabled
    }

    private static var rpeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    private var isMuted: Bool { colorMode == .disabled }

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            leadingStatus

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    title

                    if let interval = WorkoutRoutineSetCell.repetitionIntervalString(minRepetitions: workoutSet.minTargetRepetitions?.intValue, maxRepetitions: workoutSet.maxTargetRepetitions?.intValue) {
                        Text(interval)
                            .font(.forgeCaption)
                            .foregroundColor(.forgeSecondaryLabel)
                    }
                }

                if let comment = workoutSet.comment {
                    Text(comment.enquoted)
                        .lineLimit(1)
                        .font(.forgeCaption.italic())
                        .foregroundColor(.forgeSecondaryLabel)
                }
            }

            Spacer(minLength: Theme.Spacing.s)

            if let rpe = workoutSet.rpeValue {
                rpePill(rpe)
            }

            if workoutSet.isPersonalRecord ?? false {
                Image(systemName: "trophy.fill")
                    .font(.caption)
                    .foregroundColor(isMuted ? .forgeSecondaryLabel : .forgeWarning)
                    .accessibilityLabel("Personal record")
            }

            numberBadge
        }
        .padding(.vertical, Theme.Spacing.xxs)
    }

    @ViewBuilder private var leadingStatus: some View {
        if showUpNextIndicator {
            Image(systemName: "chevron.right.circle.fill")
                .foregroundColor(.forgeAccent)
        } else if showCompleted {
            if workoutSet.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(isMuted ? .forgeSecondaryLabel : .forgeSuccess)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.forgeSeparator)
            }
        }
    }

    @ViewBuilder private var title: some View {
        if isPlaceholder {
            Text("Set")
                .font(.forgeValue)
                .foregroundColor(.forgeSecondaryLabel)
        } else {
            Text(workoutSet.displayTitle(weightUnit: settingsStore.weightUnit))
                .font(.forgeValue)
                .foregroundColor(isMuted ? .forgeSecondaryLabel : .forgeLabel)
                .background(selectionBorder)
        }
    }

    @ViewBuilder private var selectionBorder: some View {
        if colorMode == .selected {
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .stroke(Color.forgeAccent)
                .padding(-Theme.Spacing.xs)
        }
    }

    private func rpePill(_ rpe: Double) -> some View {
        Text("RPE " + (Self.rpeFormatter.string(from: NSNumber(value: rpe)) ?? String(format: "%.1f", rpe)))
            .font(.caption)
            .foregroundColor(.forgeSecondaryLabel)
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xxs)
            .background(Capsule().stroke(Color.forgeSeparator))
    }

    private var numberBadge: some View {
        ZStack {
            Circle().fill(Color.forgeBackground)
            if let tag = workoutSet.tagValue, let letter = tag.title.first {
                Text(letter.uppercased())
                    .font(.forgeCaption.weight(.semibold))
                    .foregroundColor(tag.color)
            } else {
                Text("\(index)")
                    .font(.forgeCaption.monospacedDigit())
                    .foregroundColor(.forgeSecondaryLabel)
            }
        }
        .frame(width: 26, height: 26)
    }
}

#if DEBUG
struct WorkoutSetCell_Previews : PreviewProvider {
    static var workoutSet1: WorkoutSet = {
        let set = WorkoutSet(context: MockWorkoutData.metric.context)
        set.weightValue = 82.5
        set.repetitionsValue = 5
        return set
    }()

    static var workoutSet2: WorkoutSet = {
        let set = WorkoutSet(context: MockWorkoutData.metric.context)
        set.weightValue = 82.5
        set.repetitionsValue = 5
        set.tagValue = .dropSet
        set.comment = "This is a comment"
        set.isCompleted = true
        return set
    }()

    static var workoutSet4: WorkoutSet = {
        let set = WorkoutSet(context: MockWorkoutData.metric.context)
        set.weightValue = 82.5
        set.repetitionsValue = 5
        set.maxTargetRepetitionsValue = 12
        set.rpeValue = 7.5
        set.isCompleted = true
        return set
    }()

    static var previews: some View {
        List {
            Section {
                WorkoutSetCell(workoutSet: workoutSet4, index: 1, showCompleted: true)
                WorkoutSetCell(workoutSet: workoutSet1, index: 2, colorMode: .selected, showUpNextIndicator: true)
                WorkoutSetCell(workoutSet: workoutSet1, index: 3, showCompleted: true)
                WorkoutSetCell(workoutSet: workoutSet2, index: 4)
            }
        }
        .listStyleCompat_InsetGroupedListStyle()
        .mockEnvironment(weightUnit: .metric)
    }
}
#endif
