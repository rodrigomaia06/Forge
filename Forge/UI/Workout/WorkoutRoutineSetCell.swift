//
//  WorkoutRoutineSetCell.swift
//  Iron
//
//  Created by Karim Abou Zeid on 21.03.20.
//  Copyright © 2020 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import WorkoutDataKit

struct WorkoutRoutineSetCell: View {
    @ObservedObject var workoutRoutineSet: WorkoutRoutineSet
    let index: Int
    
    var isSelected = false
    
    private var repetitionIntervalString: String? {
       return Self.repetitionIntervalString(
                minRepetitions: workoutRoutineSet.minRepetitions?.intValue,
                maxRepetitions: workoutRoutineSet.maxRepetitions?.intValue
       )
    }
    
    private var tagColor: Color? { workoutRoutineSet.tagValue?.color }

    // The number chip on the left, tinted by set type, mirrors the live workout row.
    private var numberChip: some View {
        Text("\(index)")
            .font(.forgeCaption)
            .foregroundColor(tagColor ?? .forgeSecondaryLabel)
            .frame(width: 28, height: 28)
            .background(Circle().fill((tagColor ?? .forgeSecondaryLabel).opacity(tagColor == nil ? 0.14 : 0.22)))
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            numberChip

            // Wraps only when it does not fit: a short comment stays on one line beside the chip, a
            // long one breaks rather than being cut off mid-word. Three lines keeps a row from
            // growing without bound.
            workoutRoutineSet.comment.map {
                Text($0.enquoted)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .font(Font.caption.italic())
                    .foregroundColor(.secondary)
            }

            Spacer()

            // The rep target sits in a field like the live workout's reps column; the selected set is
            // outlined, and the bottom draggers edit it.
            Text(repetitionIntervalString ?? "—")
                .font(.forgeValue)
                .multilineTextAlignment(.center)
                .padding(.vertical, 7)
                .frame(minWidth: 64)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(.tertiarySystemFill)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? Color.forgeAccent : Color.clear, lineWidth: 2)
                )
            Text("reps")
                .font(.forgeCaption)
                .foregroundColor(.forgeSecondaryLabel)
        }
        .contentShape(Rectangle())
    }
}

extension WorkoutRoutineSetCell {
    static func repetitionIntervalString(minRepetitions: Int?, maxRepetitions: Int?) -> String? {
        if let minRepetitions = minRepetitions {
            if let maxRepetitions = maxRepetitions {
                // NOTE: this is an en-dash and not a hyphen
                return "\(minRepetitions == maxRepetitions ? "\(maxRepetitions)" : "\(minRepetitions)–\(maxRepetitions)")"
            } else {
                return "\(minRepetitions)+"
            }
        } else if let maxRepetitions = maxRepetitions {
            return "\(maxRepetitions)-"
        } else {
            return nil
        }
    }
}

#if DEBUG
struct WorkoutRoutineSetCell_Previews: PreviewProvider {
    static var workoutRoutineSet1: WorkoutRoutineSet = {
        let set = WorkoutRoutineSet(context: MockWorkoutData.metric.context)
        set.minRepetitionsValue = 5
        set.maxRepetitionsValue = 5
        return set
    }()
    
    static var workoutRoutineSet2: WorkoutRoutineSet = {
        let set = WorkoutRoutineSet(context: MockWorkoutData.metric.context)
        set.minRepetitionsValue = 8
        set.maxRepetitionsValue = 12
        return set
    }()
    
    static var workoutRoutineSet3: WorkoutRoutineSet = {
        let set = WorkoutRoutineSet(context: MockWorkoutData.metric.context)
        set.minRepetitionsValue = 5
        return set
    }()
    
    static var workoutRoutineSet4: WorkoutRoutineSet = {
        let set = WorkoutRoutineSet(context: MockWorkoutData.metric.context)
        set.maxRepetitionsValue = 5
        return set
    }()
    
    static var workoutRoutineSet5: WorkoutRoutineSet = {
        let set = WorkoutRoutineSet(context: MockWorkoutData.metric.context)
        return set
    }()
    
    static var workoutRoutineSet6: WorkoutRoutineSet = {
        let set = WorkoutRoutineSet(context: MockWorkoutData.metric.context)
        set.tagValue = .dropSet
        set.comment = "This is a comment"
        return set
    }()
    
    static var previews: some View {
        List {
            WorkoutRoutineSetCell(workoutRoutineSet: workoutRoutineSet1, index: 1, isSelected: false)
            
            WorkoutRoutineSetCell(workoutRoutineSet: workoutRoutineSet2, index: 2, isSelected: true)
            
            WorkoutRoutineSetCell(workoutRoutineSet: workoutRoutineSet3, index: 3, isSelected: false)
            
            WorkoutRoutineSetCell(workoutRoutineSet: workoutRoutineSet4, index: 4, isSelected: false)
            
            WorkoutRoutineSetCell(workoutRoutineSet: workoutRoutineSet5, index: 5, isSelected: false)
                
            WorkoutRoutineSetCell(workoutRoutineSet: workoutRoutineSet6, index: 6, isSelected: true)
        }
        .listStyle(GroupedListStyle())
        .mockEnvironment(weightUnit: .metric)
    }
}
#endif
