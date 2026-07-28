//
//  ForgeTabBar.swift
//  Forge
//
//  The custom floating "dock" — a frosted-glass capsule with icon-only items and a sliding
//  selection pill behind the active tab (Instagram-style). Used as the app's real navigation
//  (see ContentView). Content scrolls behind it so the glass reads as glass.
//

import SwiftUI

struct ForgeTabBar: View {
    @Binding var selection: SceneState.Tab
    @Namespace private var pill

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
                    guard selection != item.tab else { return }
                    Haptics.impact(.medium)
                    selection = item.tab
                } label: {
                    ZStack {
                        if selection == item.tab {
                            Capsule(style: .continuous)
                                .fill(Color.forgeLabel.opacity(0.16))
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                        Image(systemName: item.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(selection == item.tab ? .forgeLabel : .forgeSecondaryLabel)
                    }
                    .frame(width: 56, height: 38)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(item.title)
            }
        }
        .padding(Theme.Spacing.xs)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
                .shadow(color: Color.black.opacity(0.35), radius: 18, y: 8)
        )
        .animation(.snappy(duration: 0.28), value: selection)
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
