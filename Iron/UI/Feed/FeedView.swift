//
//  FeedView.swift
//  Forge
//
//  The Home dashboard: greeting, quick stats, an activity calendar (a proper month grid you
//  can tap to filter workouts by day, expandable to a year of separated month grids), and
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
    @State private var calendarExpanded = false
    @State private var selectedDate: Date?

    private var cal: Calendar {
        var c = Calendar.current
        c.firstWeekday = settingsStore.firstWeekday
        return c
    }

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
            statTile("\(count(in: .weekOfYear))", "This week")
            statTile("\(count(in: .month))", "This month")
            statTile(shortVolume(monthVolume), "Volume")
        }
    }

    private func statTile(_ value: String, _ label: String) -> some View {
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
                withAnimation(.snappy(duration: 0.28)) {
                    calendarExpanded.toggle()
                    if calendarExpanded { selectedDate = nil }
                }
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
                yearCalendar
            } else {
                monthCalendar
            }
        }
    }

    private var monthString: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: Date()).uppercased()
    }

    private var yearString: String { String(cal.component(.year, from: Date())) }

    private var weekdaySymbols: [String] {
        let syms = cal.veryShortStandaloneWeekdaySymbols
        let start = cal.firstWeekday - 1
        return Array(syms[start...] + syms[..<start])
    }

    // A tappable month grid; tapping a day filters the recent list.
    private var monthCalendar: some View {
        let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        let firstWeekday = (cal.component(.weekday, from: firstOfMonth) - cal.firstWeekday + 7) % 7
        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        let active = activeDays(inSameMonthAs: firstOfMonth)
        let rows = Int(ceil(Double(firstWeekday + daysInMonth) / 7.0))

        return VStack(spacing: Theme.Spacing.xs) {
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { s in
                    Text(s).font(.system(size: 10, weight: .medium)).foregroundColor(.forgeSecondaryLabel).frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let day = row * 7 + col - firstWeekday + 1
                        dayCell(day: day, valid: day >= 1 && day <= daysInMonth, active: active.contains(day), firstOfMonth: firstOfMonth)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(day: Int, valid: Bool, active: Bool, firstOfMonth: Date) -> some View {
        if valid, let date = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
            let isSelected = selectedDate.map { cal.isDate($0, inSameDayAs: date) } ?? false
            Button {
                Haptics.selection()
                withAnimation(.snappy(duration: 0.2)) {
                    selectedDate = isSelected ? nil : date
                }
            } label: {
                Text("\(day)")
                    .font(.system(size: 13, weight: active || isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .forgeBackground : (active ? .forgeLabel : .forgeSecondaryLabel))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(isSelected ? Color.forgeAccent : (active ? Color.forgeSurface : Color.clear)))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(height: 34).frame(maxWidth: .infinity)
        }
    }

    // The full year as 12 separated month grids.
    private var yearCalendar: some View {
        let year = cal.component(.year, from: Date())
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Spacing.l) {
            ForEach(1...12, id: \.self) { month in
                miniMonth(year: year, month: month)
            }
        }
    }

    private func miniMonth(year: Int, month: Int) -> some View {
        let firstOfMonth = cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        let firstWeekday = (cal.component(.weekday, from: firstOfMonth) - cal.firstWeekday + 7) % 7
        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        let active: Set<Int> = Set(workouts.compactMap { w in
            guard let s = w.start, cal.component(.year, from: s) == year, cal.component(.month, from: s) == month else { return nil }
            return cal.component(.day, from: s)
        })
        let rows = Int(ceil(Double(firstWeekday + daysInMonth) / 7.0))
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(cal.shortStandaloneMonthSymbols[month - 1].uppercased())
                .font(.system(size: 11, weight: .semibold)).foregroundColor(.forgeSecondaryLabel)
            VStack(spacing: 2) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<7, id: \.self) { col in
                            let day = row * 7 + col - firstWeekday + 1
                            let valid = day >= 1 && day <= daysInMonth
                            Circle()
                                .fill(valid ? (active.contains(day) ? Color.forgeAccent : Color.forgeSurface) : Color.clear)
                                .aspectRatio(1, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func activeDays(inSameMonthAs date: Date) -> Set<Int> {
        Set(workouts.compactMap { w in
            guard let s = w.start, cal.isDate(s, equalTo: date, toGranularity: .month) else { return nil }
            return cal.component(.day, from: s)
        })
    }

    // MARK: Recent workouts (filtered by the selected day)

    private var recentWorkouts: [Workout] {
        if let d = selectedDate {
            return workouts.filter { w in
                guard let s = w.start else { return false }
                return cal.isDate(s, inSameDayAs: d)
            }
        }
        return Array(workouts.prefix(6))
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text(recentTitle).font(.forgeSectionLabel).tracking(2).foregroundColor(.forgeSecondaryLabel)
                Spacer()
                if selectedDate != nil {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { selectedDate = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill").font(.callout).foregroundColor(.forgeSecondaryLabel)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear day filter")
                }
            }
            let list = recentWorkouts
            if list.isEmpty {
                Text(selectedDate == nil ? "No workouts yet." : "No workouts that day.")
                    .font(.forgeCaption).foregroundColor(.forgeSecondaryLabel)
                    .padding(.vertical, Theme.Spacing.m)
            } else {
                ForEach(list, id: \.objectID) { workout in
                    workoutCard(workout)
                }
            }
        }
    }

    private var recentTitle: String {
        guard let d = selectedDate else { return "RECENT" }
        let f = DateFormatter(); f.dateFormat = "MMMM d"
        return f.string(from: d).uppercased()
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
