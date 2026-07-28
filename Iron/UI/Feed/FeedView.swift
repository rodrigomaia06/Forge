//
//  FeedView.swift
//  Forge
//
//  The Home tab: a calm greeting, an activity heat-grid for the current month, and quiet
//  recent-workout cards — all from real data, on Forge's dark canvas.
//

import SwiftUI
import CoreData
import WorkoutDataKit

struct FeedView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var sceneState: SceneState

    @FetchRequest private var workouts: FetchedResults<Workout>

    init() {
        let request: NSFetchRequest<Workout> = Workout.fetchRequest()
        request.predicate = NSPredicate(format: "\(#keyPath(Workout.isCurrentWorkout)) != %@", NSNumber(value: true))
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Workout.start, ascending: false)]
        _workouts = FetchRequest(fetchRequest: request)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                header
                calendar
                recent
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.xxl)
            .padding(.bottom, Theme.Spacing.l)
        }
        .background(Color.forgeBackground.ignoresSafeArea())
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(greeting).font(.forgeGreeting).foregroundColor(.forgeLabel)
                Text("Ready to train?").font(.forgeCaption).foregroundColor(.forgeSecondaryLabel)
            }
            Spacer()
            Button {
                Haptics.impact()
                sceneState.selectedTab = .workout
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.forgeBackground)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.forgeAccent))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start workout")
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: Activity heat-grid

    private var calendar: some View {
        let cal = Calendar.current
        let now = Date()
        let days = cal.range(of: .day, in: .month, for: now)?.count ?? 30
        let active: Set<Int> = Set(workouts.compactMap { w in
            guard let start = w.start, cal.isDate(start, equalTo: now, toGranularity: .month) else { return nil }
            return cal.component(.day, from: start)
        })
        let rows = Int(ceil(Double(days) / 7.0))

        return VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text(monthLabel).font(.forgeSectionLabel).tracking(2).foregroundColor(.forgeSecondaryLabel)
            VStack(spacing: Theme.Spacing.s) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: Theme.Spacing.s) {
                        ForEach(0..<7, id: \.self) { col in
                            let day = row * 7 + col + 1
                            Circle()
                                .fill(day <= days ? (active.contains(day) ? Color.forgeAccent : Color.forgeSurface) : Color.clear)
                                .frame(width: 9, height: 9)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private var monthLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: Date()).uppercased()
    }

    // MARK: Recent workouts

    private var recent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("RECENT").font(.forgeSectionLabel).tracking(2).foregroundColor(.forgeSecondaryLabel)
            if workouts.isEmpty {
                Text("No workouts yet.")
                    .font(.forgeCaption).foregroundColor(.forgeSecondaryLabel)
                    .padding(.vertical, Theme.Spacing.m)
            } else {
                ForEach(Array(workouts.prefix(6)), id: \.objectID) { workout in
                    workoutCard(workout)
                }
            }
        }
    }

    private func workoutCard(_ workout: Workout) -> some View {
        let s = stats(workout)
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(dateLabel(workout.start)).font(.forgeSectionLabel).tracking(1).foregroundColor(.forgeSecondaryLabel)
            Text(workout.title ?? "Workout").font(.forgeHeadline).foregroundColor(.forgeLabel)
            Text("\(s.exercises) exercises · \(s.sets) sets · \(volumeString(s.volume))")
                .font(.forgeCaption).foregroundColor(.forgeSecondaryLabel)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous).fill(Color.forgeSurface))
    }

    private func stats(_ workout: Workout) -> (exercises: Int, sets: Int, volume: Double) {
        let exercises = (workout.workoutExercises?.array as? [WorkoutExercise]) ?? []
        let sets = exercises.flatMap { ($0.workoutSets?.array as? [WorkoutSet]) ?? [] }
        let volume = sets.reduce(0.0) { $0 + $1.weightValue * Double($1.repetitionsValue) }
        return (exercises.count, sets.count, volume)
    }

    private func dateLabel(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: date).uppercased()
    }

    private func volumeString(_ kg: Double) -> String {
        let unit = settingsStore.weightUnit
        let value = WeightUnit.convert(weight: kg, from: .metric, to: unit)
        let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0
        let number = f.string(from: NSNumber(value: value)) ?? String(Int(value))
        return "\(number) \(unit.unit.symbol)"
    }
}

#if DEBUG
struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        FeedView()
            .mockEnvironment(weightUnit: .metric)
            .preferredColorScheme(.dark)
    }
}
#endif
