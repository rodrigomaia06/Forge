//
//  ExerciseStatisticsView.swift
//  Forge
//
//  Created by Karim Abou Zeid on 06.07.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import DGCharts
import WorkoutDataKit

struct ExerciseStatisticsView : View {
    var exercise: Exercise

    @State private var timeFrame: WorkoutExerciseChartData.TimeFrame = .threeMonths

    var body: some View {
        List {
            Section {
                Picker("Time frame", selection: $timeFrame) {
                    ForEach(WorkoutExerciseChartData.TimeFrame.allCases, id: \.self) { timeFrame in
                        Text(timeFrame.title).tag(timeFrame)
                    }
                }
                .pickerStyle(.segmented)
            }
            ForEach(WorkoutExerciseChartData.MeasurementType.allCases, id: \.self) { measurementType in
                Section {
                    ExerciseChartViewCell(exercise: self.exercise, measurementType: measurementType, timeFrame: timeFrame)
                }
            }
        }
        .listStyleCompat_InsetGroupedListStyle()
    }
}

#if DEBUG
struct ExerciseStatisticsView_Previews : PreviewProvider {
    static var previews: some View {
        ExerciseStatisticsView(exercise: ExerciseStore.shared.exercises.first(where: { $0.everkineticId == 99 })!)
            .mockEnvironment(weightUnit: .metric)
    }
}
#endif
