//
//  ForgeHomeView.swift
//  Forge
//
//  Static mock of the Home dashboard for CI screenshots (the live FeedView needs real
//  data to render): greeting, quick-stat tiles, a full-year activity heat-grid, and
//  recent-workout cards. Mirrors FeedView's design so we can review the look.
//

import SwiftUI

struct ForgeHomeView: View {
    private let activeWeeks: Set<Int> = [1, 2, 4, 5, 7, 8, 9, 11, 12, 14, 16, 17, 19, 20, 22, 24, 25]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            header
            stats
            activity
            recent
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

    private var stats: some View {
        HStack(spacing: Theme.Spacing.m) {
            statTile("3", "This week")
            statTile("11", "This month")
            statTile("94.2k kg", "Volume")
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

    private var activity: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text("ACTIVITY 2026").font(.forgeSectionLabel).tracking(2).foregroundColor(.forgeSecondaryLabel)
                Spacer()
                Image(systemName: "chevron.up").font(.caption.weight(.semibold)).foregroundColor(.forgeSecondaryLabel)
            }
            VStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { weekday in
                    HStack(spacing: 3) {
                        ForEach(0..<26, id: \.self) { week in
                            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                .fill(activeWeeks.contains(week) && (week + weekday) % 3 == 0 ? Color.forgeAccent : Color.forgeSurface)
                                .aspectRatio(1, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("RECENT").font(.forgeSectionLabel).tracking(2).foregroundColor(.forgeSecondaryLabel)
            card("MARCH 28", "Chest Day", "5 exercises · 20 sets · 8,040 kg")
            card("MARCH 26", "Back Day", "6 exercises · 22 sets · 12,410 kg")
        }
    }

    private func card(_ date: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(date).font(.forgeSectionLabel).tracking(1).foregroundColor(.forgeSecondaryLabel)
            Text(title).font(.forgeHeadline).foregroundColor(.forgeLabel)
            Text(detail).font(.forgeCaption).foregroundColor(.forgeSecondaryLabel)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous).fill(Color.forgeSurface))
    }
}

#if DEBUG
struct ForgeHomeView_Previews: PreviewProvider {
    static var previews: some View {
        ForgeHomeView().preferredColorScheme(.dark)
    }
}
#endif
