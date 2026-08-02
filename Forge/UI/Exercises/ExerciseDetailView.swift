//
//  ExerciseDetailView.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 04.07.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import WorkoutDataKit

struct ExerciseDetailView : View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @Environment(\.managedObjectContext) var managedObjectContext
    var exercise: Exercise


    @State private var activeSheet: SheetType?
    
    private enum SheetType: Identifiable {
        case statistics
        case history
        case editExercise
        
        var id: Self { self }
    }
    
    private func sheetView(type: SheetType) -> AnyView {
        switch type {
        case .history:
            return exerciseHistorySheet.typeErased
        case .statistics:
            return exerciseStatisticsSheet.typeErased
        case .editExercise:
            return EditCustomExerciseSheet(exercise: exercise)
                .environmentObject(self.exerciseStore)
                .typeErased
        }
    }
    
    private var closeSheetButton: some View {
        Button("Close") {
            self.activeSheet = nil
        }
    }
    
    private var exerciseHistorySheet: some View {
        NavigationStack {
            ExerciseHistoryView(exercise: self.exercise)
                .navigationBarTitle("History", displayMode: .inline)
                .navigationBarItems(leading: closeSheetButton)
                .environmentObject(self.settingsStore)
                .environment(\.managedObjectContext, self.managedObjectContext)
        }
    }
    
    private var exerciseStatisticsSheet: some View {
        NavigationStack {
            ExerciseStatisticsView(exercise: self.exercise)
                .navigationBarTitle("Statistics", displayMode: .inline)
                .navigationBarItems(leading: closeSheetButton)
                .environmentObject(self.settingsStore)
                .environment(\.managedObjectContext, self.managedObjectContext)
        }
    }
    
    private var descriptionSection: some View {
        Section {
            Text(self.exercise.description ?? "")
                .lineLimit(nil)
        }
    }
    
    private var muscleSection: some View {
        Section(header: Text("Muscles".uppercased())) {
            ForEach(self.exercise.primaryMuscleCommonName, id: \.hashValue) { primaryMuscle in
                HStack {
                    Text(primaryMuscle.capitalized)
                    Spacer()
                    Text("Primary")
                        .foregroundColor(.secondary)
                }
            }
            ForEach(self.exercise.secondaryMuscleCommonName, id: \.hashValue) { secondaryMuscle in
                HStack {
                    Text(secondaryMuscle.capitalized)
                    Spacer()
                    Text("Secondary")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var tipsSection: some View {
        Section(header: Text("Tips".uppercased())) {
            ForEach(self.exercise.tips, id: \.hashValue) { tip in
                Text(tip as String)
                    .lineLimit(nil)
            }
        }
    }
    
    private var referencesSection: some View {
        Section(header: Text("References".uppercased())) {
            ForEach(self.exercise.references, id: \.hashValue) { reference in
                Button(reference as String) {
                    if let url = URL(string: reference) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }
    
    private var aliasSection: some View {
        Section(header: Text("Also known as".uppercased())) {
            ForEach(self.exercise.alias, id: \.hashValue) { alias in
                Text(alias)
            }
        }
    }
    
    @ViewBuilder private var optionsMenu: some View {
        Button { self.activeSheet = .history } label: {
            Label("History", systemImage: "clock.arrow.circlepath")
        }
        Button { self.activeSheet = .statistics } label: {
            Label("Statistics", systemImage: "chart.xyaxis.line")
        }
        if exerciseStore.isHidden(exercise: exercise) {
            Button { self.exerciseStore.show(exercise: self.exercise) } label: {
                Label("Unhide", systemImage: "eye")
            }
        } else if !exercise.isCustom {
            Button { self.exerciseStore.hide(exercise: self.exercise) } label: {
                Label("Hide", systemImage: "eye.slash")
            }
        }
    }
    
    private var restTimeSection: some View {
        Section(footer: Text("Rest timer started after completing a set of this exercise. \"Default\" uses the rest time set in General.")) {
            Picker("Rest Time", selection: Binding(
                get: { exerciseStore.restTime(forExercise: exercise.uuid) },
                set: { exerciseStore.setRestTime($0, forExercise: exercise.uuid) }
            )) {
                Text("Default").tag(TimeInterval?.none)
                ForEach(restTimerCustomTimes, id: \.self) { time in
                    Text(restTimerDurationFormatter.string(from: time) ?? "").tag(TimeInterval?.some(time))
                }
            }
        }
    }

    var body: some View {
        // A plain List, not a GeometryReader wrapping one. The reader existed only to size the
        // exercise illustration, and it made the whole list re-evaluate on every size change.
        List {
            restTimeSection

            if exercise.description != nil {
                descriptionSection
            }

            if !(exercise.primaryMuscleCommonName.isEmpty && exercise.secondaryMuscleCommonName.isEmpty) {
                muscleSection
            }

            if !exercise.tips.isEmpty {
                tipsSection
            }

            if !exercise.references.isEmpty {
                referencesSection
            }

            if !exercise.alias.isEmpty {
                aliasSection
            }
        }
        .listStyleCompat_InsetGroupedListStyle()
        .sheet(item: $activeSheet) { type in
            self.sheetView(type: type)
        }
        .navigationBarTitle(Text(exercise.title), displayMode: .inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    optionsMenu
                } label: {
                    Image(systemName: "ellipsis")
                        .imageScale(.large)
                }
                if exercise.isCustom {
                    Button("Edit") {
                        self.activeSheet = .editExercise
                    }
                }
            }
        }
    }
}

#if DEBUG
struct ExerciseDetailView_Previews : PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ExerciseDetailView(exercise: ExerciseStore.shared.exercises.first(where: { $0.everkineticId == 99 })!)
                .mockEnvironment(weightUnit: .metric)
        }
    }
}
#endif
