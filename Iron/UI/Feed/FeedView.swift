//
//  FeedView.swift
//  Forge
//
//  The Home dashboard: greeting, quick stats, an activity calendar that expands from the
//  current month to a full-year heat-grid, and recent-workout cards — all from real data,
//  on Forge's dark canvas.
//

import SwiftUI
import CoreData
import WorkoutDataKit

struct FeedView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var sceneState: SceneState

    @FetchRequest private var workouts: FetchedResults<Workout>
    @State private var calendarExpanded = false

    private let cal = Calendar.current

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
                statsRow
                activitySection
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
        switch cal.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: Quick stats

    private var statsRow: some View {
        HStack(spacing: Theme.Spacing.m) {
            statTile(value: "\(count(in: .weekOfYear))", label: "This week")
            statTile(value: "\(count(in: .month))", label: "This month")
            statTile(value: shortVolume(monthVolume), label: "Volume")
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(value).font(.forgeMetric).foregroundColor(.forgeLabel)
            Text(label).font(.forgeCaption).foregroundColor(.forgeSecondaryLabel)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous).fill(Color.forgeSurface))
    }

    private func count(in unit: Calendar.Component) -> Int {
        workouts.filter { w in
            guard let s = w.start else { return false }
            return cal.isDate(s, equalTo: Date(), toGranularity: unit)
        }.count
    }

    private var monthVolume: Double {
        workouts.reduce(0.0) { total, w in
            guard let s = w.start, cal.isDate(s, equalTo: Date(), toGranularity: .month) else { return total }
            return total + volume(of: w)
        }
    }

    // MARK: Activity calendar (month <-> year)

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Button {
                withAnimation(.snappy(duration: 0.28)) { calendarExpanded.toggle() }
            } label: {
                HStack {
                    Text(calendarExpanded ? "ACTIVITY \(yearString)" : monthString)
                        .font(.forgeSectionLabel).tracking(2)
                        .foregroundColor(.forgeSecondaryLabel)
                    Spacer()
                    Image(systemName: calendarExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.forgeSecondaryLabel)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if calendarExpanded {
                yearHeatmap
            } else {
                monthGrid
            }
        }
    }

    private var monthString: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: Date()).uppercased()
    }

    private var yearString: String { String(cal.component(.year, from: Date())) }

    private var monthGrid: some View {
        let now = Date()
        let days = cal.range(of: .day, in: .month, for: now)?.count ?? 30
        let active: Set<Int> = Set(workouts.compactMap { w in
            guard let s = w.start, cal.isDate(s, equalTo: now, toGranularity: .month) else { return nil }
            return cal.component(.day, from: s)
        })
        let rows = Int(ceil(Double(days) / 7.0))
        return VStack(spacing: Theme.Spacing.s) {
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

    private var yearHeatmap: some View {
        let year = cal.component(.year, from: Date())
        let startOfYear = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
        let daysInYear = cal.range(of: .day, in: .year, for: startOfYear)?.count ?? 365
        let firstWeekday = (cal.component(.weekday, from: startOfYear) - cal.firstWeekday + 7) % 7
        let weeks = Int(ceil(Double(firstWeekday + daysInYear) / 7.0))
        let active: Set<Int> = Set(workouts.compactMap { w in
            guard let s = w.start, cal.component(.year, from: s) == year else { return nil }
            return cal.ordinality(of: .day, in: .year, for: s)
        })
        return VStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { weekday in
                HStack(spacing: 3) {
                    ForEach(0..<weeks, id: \.self) { week in
                        let dayIndex = week * 7 + weekday - firstWeekday   // 0-based day of year
                        let inYear = dayIndex >= 0 && dayIndex < daysInYear
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(inYear ? (active.contains(dayIndex + 1) ? Color.forgeAccent : Color.forgeSurface) : Color.clear)
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
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

    // MARK: Data helpers

    private func stats(_ workout: Workout) -> (exercises: Int, sets: Int, volume: Double) {
        let exercises = (workout.workoutExercises?.array as? [WorkoutExercise]) ?? []
        let sets = exercises.flatMap { ($0.workoutSets?.array as? [WorkoutSet]) ?? [] }
        let volume = sets.reduce(0.0) { $0 + $1.weightValue * Double($1.repetitionsValue) }
        return (exercises.count, sets.count, volume)
    }

    private func volume(of workout: Workout) -> Double { stats(workout).volume }

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

    private func shortVolume(_ kg: Double) -> String {
        let unit = settingsStore.weightUnit
        let value = WeightUnit.convert(weight: kg, from: .metric, to: unit)
        let symbol = unit.unit.symbol
        if value >= 1000 {
            return String(format: "%.1fk %@", value / 1000, symbol)
        }
        return "\(Int(value)) \(symbol)"
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
