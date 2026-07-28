//
//  ForgeTabBar.swift
//  Forge
//
//  The custom floating "dock" tab bar used as the app's real navigation (see ContentView).
//  A rounded surface pill with icon + label items on the design tokens.
//

import SwiftUI

struct ForgeTabBar: View {
    @Binding var selection: SceneState.Tab

    private struct Item {
        let tab: SceneState.Tab
        let title: String
        let icon: String
    }

    private let items: [Item] = [
        Item(tab: .feed,      title: "Home",      icon: "house"),
        Item(tab: .history,   title: "History",   icon: "clock"),
        Item(tab: .workout,   title: "Workout",   icon: "dumbbell"),
        Item(tab: .exercises, title: "Exercises", icon: "square.stack"),
        Item(tab: .settings,  title: "Settings",  icon: "gearshape"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                Button {
                    selection = item.tab
                } label: {
                    VStack(spacing: Theme.Spacing.xxs) {
                        Image(systemName: item.icon)
                            .font(.system(size: 18, weight: .medium))
                        Text(item.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(selection == item.tab ? .forgeLabel : .forgeSecondaryLabel)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Theme.Layout.minTapTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
            }
        }
        .padding(.horizontal, Theme.Spacing.s)
        .background(
            Capsule(style: .continuous)
                .fill(Color.forgeSurface)
                .overlay(Capsule(style: .continuous).strokeBorder(Color.forgeSeparator, lineWidth: 0.5))
                .shadow(color: Color.black.opacity(0.35), radius: 16, y: 6)
        )
    }
}

#if DEBUG
struct ForgeTabBar_Previews: PreviewProvider {
    static var previews: some View {
        ForgeTabBar(selection: .constant(.workout))
            .padding()
            .background(Color.forgeBackground)
            .preferredColorScheme(.dark)
            .previewLayout(.sizeThatFits)
    }
}
#endif
