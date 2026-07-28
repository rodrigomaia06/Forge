//
//  ForgeHomeView.swift
//  Forge
//
//  Dark, minimal home screen (mock layout for review) in the direction of the reference:
//  a calm greeting, an activity heat-grid, quiet recent-workout cards, a floating add
//  button, and a custom Workouts / Progress / Settings tab bar. Value-based so it renders
//  in CI screenshots; wired into the live app once the look is agreed.
//

import SwiftUI

struct ForgeHomeView: View {
    // Example active days for the heat-grid.
    private let activeDays: Set<Int> = [2, 3, 5, 9, 10, 12, 16, 17, 19, 23, 24, 26, 28]

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            header
            calendar
            workouts
            Spacer(minLength: Theme.Spacing.l)
            tabBar
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.xxl)
        .padding(.bottom, Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.forgeBackground)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Good afternoon").font(.forgeGreeting).foregroundColor(.forgeLabel)
                Text("Ready to train?").font(.forgeCaption).foregroundColor(.forgeSecondaryLabel)
            }
            Spacer()
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.forgeBackground)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.forgeAccent))
        }
    }

    private var calendar: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("MARCH 2026")
                .font(.forgeSectionLabel).tracking(2)
                .foregroundColor(.forgeSecondaryLabel)
            VStack(spacing: Theme.Spacing.s) {
                ForEach(0..<5, id: \.self) { row in
                    HStack(spacing: Theme.Spacing.s) {
                        ForEach(0..<7, id: \.self) { col in
                            let day = row * 7 + col + 1
                            Circle()
                                .fill(dotColor(day: day))
                                .frame(width: 9, height: 9)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func dotColor(day: Int) -> Color {
        guard day <= 31 else { return .clear }
        return activeDays.contains(day) ? .forgeAccent : .forgeSurface
    }

    private var workouts: some View {
        VStack(spacing: Theme.Spacing.m) {
            workoutCard(date: "MARCH 28", title: "Chest Day", detail: "5 exercises · 20 sets · 8,040 kg")
            workoutCard(date: "MARCH 26", title: "Back Day", detail: "6 exercises · 22 sets · 12,410 kg")
            workoutCard(date: "MARCH 24", title: "Arms", detail: "4 exercises · 14 sets · 3,120 kg")
        }
    }

    private func workoutCard(date: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(date).font(.forgeSectionLabel).tracking(1).foregroundColor(.forgeSecondaryLabel)
            Text(title).font(.forgeHeadline).foregroundColor(.forgeLabel)
            Text(detail).font(.forgeCaption).foregroundColor(.forgeSecondaryLabel)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous).fill(Color.forgeSurface))
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabItem("Workouts", "dumbbell", selected: true)
            tabItem("Progress", "chart.line.uptrend.xyaxis", selected: false)
            tabItem("Settings", "gearshape", selected: false)
        }
        .padding(.vertical, Theme.Spacing.m)
        .padding(.horizontal, Theme.Spacing.l)
        .background(Capsule(style: .continuous).fill(Color.forgeSurface))
    }

    private func tabItem(_ title: String, _ icon: String, selected: Bool) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: icon).font(.system(size: 18, weight: .medium))
            Text(title).font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(selected ? .forgeLabel : .forgeSecondaryLabel)
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
struct ForgeHomeView_Previews: PreviewProvider {
    static var previews: some View {
        ForgeHomeView().preferredColorScheme(.dark)
    }
}
#endif
