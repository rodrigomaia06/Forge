//
//  FeedView.swift
//  Forge
//
//  The Home dashboard: greeting, quick stats, an activity calendar (a month grid whose days
//  filter the workout list, expandable to a year of month grids whose months also filter),
//  and recent-workout cards. The chosen day/month filter persists while the app is open
//  (the page stays alive) and clears only via the clear button or relaunch.
//

import SwiftUI
import CoreData
import WorkoutDataKit

private enum ActivityFilter: Equatable {
    case day(Date)
    case month(year: Int, month: Int)
}

struct FeedView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var sceneState: SceneState

    @FetchRequest private var workouts: FetchedResults<Workout>
    @State private var calendarExpanded = false
    @State private var filter: ActivityFilter?
    /// When set (from the year view), the calendar drills into this single month's detailed grid.
    @State private var zoomedMonth: MonthRef?

    private struct MonthRef: Equatable { let year: Int; let month: Int }

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
        NavigationStack {
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
            // Keep the custom greeting header; the nav bar only appears on pushed detail screens.
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            Text(greeting).font(.forgeGreeting).foregroundColor(.forgeLabel)
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
        .forgeCard(radius: Theme.Radius.medium)
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

    private func toggle(_ f: ActivityFilter) {
        Haptics.selection()
        withAnimation(.snappy(duration: 0.2)) {
            filter = (filter == f) ? nil : f
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            activityHeader

            if let zoom = zoomedMonth {
                monthGrid(firstOfMonth: firstOf(year: zoom.year, month: zoom.month))
            } else if calendarExpanded {
                yearCalendar
            } else {
                monthGrid(firstOfMonth: currentFirstOfMonth)
            }
        }
    }

    @ViewBuilder
    private var activityHeader: some View {
        if let zoom = zoomedMonth {
            // Zoomed into a single month: the header becomes a back affordance to the year.
            Button {
                Haptics.selection()
                withAnimation(.snappy(duration: 0.28)) { zoomedMonth = nil }
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "chevron.left").font(.caption.weight(.semibold))
                    Text(monthTitle(zoom).uppercased()).font(.forgeSectionLabel).tracking(2)
                    Spacer()
                }
                .foregroundColor(.forgeSecondaryLabel)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to year")
        } else {
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
        }
    }

    private var currentFirstOfMonth: Date {
        cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
    }

    private func firstOf(year: Int, month: Int) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    private func monthTitle(_ ref: MonthRef) -> String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: firstOf(year: ref.year, month: ref.month))
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

    private func monthGrid(firstOfMonth: Date) -> some View {
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
            let isSelected = filter == .day(date)
            Button {
                toggle(.day(date))
            } label: {
                Text("\(day)")
                    .font(.system(size: 13, weight: active || isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .forgeBackground : (active ? .forgeLabel : .forgeSecondaryLabel))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(isSelected ? Color.forgeAccent : (active ? Color.forgeSurface : Color.clear)))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(dayAccessibilityLabel(date, active: active))
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        } else {
            Color.clear.frame(height: 34).frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        }
    }

    private func dayAccessibilityLabel(_ date: Date, active: Bool) -> String {
        let f = DateFormatter(); f.dateStyle = .full; f.timeStyle = .none
        let day = f.string(from: date)
        return active ? "\(day), workout logged" : "\(day), no workout"
    }

    // The full year as smaller, tappable month grids (4 per row).
    private var yearCalendar: some View {
        let year = cal.component(.year, from: Date())
        let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.m), count: 4)
        return LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Spacing.l) {
            ForEach(1...12, id: \.self) { month in
                Button {
                    Haptics.selection()
                    withAnimation(.snappy(duration: 0.28)) {
                        zoomedMonth = MonthRef(year: year, month: month)
                        filter = .month(year: year, month: month)
                    }
                } label: {
                    miniMonth(year: year, month: month, selected: filter == .month(year: year, month: month))
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(monthAccessibilityLabel(year: year, month: month))
            }
        }
    }

    private func monthAccessibilityLabel(year: Int, month: Int) -> String {
        let name = cal.standaloneMonthSymbols[month - 1]
        let count = workouts.filter { w in
            guard let s = w.start else { return false }
            return cal.component(.year, from: s) == year && cal.component(.month, from: s) == month
        }.count
        let workoutText = count == 1 ? "1 workout" : "\(count) workouts"
        return "\(name) \(year), \(workoutText)"
    }

    private func miniMonth(year: Int, month: Int, selected: Bool) -> some View {
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
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(selected ? .forgeLabel : .forgeSecondaryLabel)
            VStack(spacing: 1.5) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 1.5) {
                        ForEach(0..<7, id: \.self) { col in
                            let day = row * 7 + col - firstWeekday + 1
                            let valid = day >= 1 && day <= daysInMonth
                            RoundedRectangle(cornerRadius: 1, style: .continuous)
                                .fill(valid ? (active.contains(day) ? Color.forgeAccent : Color.forgeSurface) : Color.clear)
                                .aspectRatio(1, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.xs)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
            .strokeBorder(selected ? Color.forgeAccent : Color.clear, lineWidth: 1))
    }

    private func activeDays(inSameMonthAs date: Date) -> Set<Int> {
        Set(workouts.compactMap { w in
            guard let s = w.start, cal.isDate(s, equalTo: date, toGranularity: .month) else { return nil }
            return cal.component(.day, from: s)
        })
    }

    // MARK: Recent workouts (filtered by the selected day / month)

    private var filteredWorkouts: [Workout] {
        switch filter {
        case .day(let d):
            return workouts.filter { w in
                guard let s = w.start else { return false }
                return cal.isDate(s, inSameDayAs: d)
            }
        case .month(let year, let month):
            return workouts.filter { w in
                guard let s = w.start else { return false }
                return cal.component(.year, from: s) == year && cal.component(.month, from: s) == month
            }
        case nil:
            return Array(workouts.prefix(6))
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text(recentTitle).font(.forgeSectionLabel).tracking(2).foregroundColor(.forgeSecondaryLabel)
                Spacer()
                if filter != nil {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { filter = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill").font(.callout).foregroundColor(.forgeSecondaryLabel)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear filter")
                }
            }
            let list = filteredWorkouts
            if list.isEmpty {
                Text(filter == nil ? "No workouts yet." : "No workouts in this period.")
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
        switch filter {
        case .day(let d):
            let f = DateFormatter(); f.dateFormat = "MMMM d"
            return f.string(from: d).uppercased()
        case .month(let year, let month):
            let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
            let comps = DateComponents(year: year, month: month, day: 1)
            return (cal.date(from: comps).map { f.string(from: $0) } ?? "").uppercased()
        case nil:
            return "RECENT"
        }
    }

    private func workoutCard(_ workout: Workout) -> some View {
        let s = stats(workout)
        // Open the workout in the History tab rather than pushing it inside the dashboard, so a
        // finished workout always lives in one place.
        return Button {
            sceneState.historyWorkoutToOpen = workout
            sceneState.selectedTab = .history
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(dateLabel(workout.start)).font(.forgeSectionLabel).tracking(1).foregroundColor(.forgeSecondaryLabel)
                Text(workout.title ?? "Workout").font(.forgeHeadline).foregroundColor(.forgeLabel)
                Text("\(s.exercises) exercises · \(s.sets) sets · \(volumeString(s.volume))\(durationSuffix(workout))")
                    .font(.forgeCaption).foregroundColor(.forgeSecondaryLabel)
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .forgeCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: Data helpers

    private func durationSuffix(_ workout: Workout) -> String {
        guard let duration = workout.duration, let text = Workout.durationFormatter.string(from: duration) else { return "" }
        return " · \(text)"
    }

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
