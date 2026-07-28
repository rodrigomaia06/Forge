//
//  ForgeTabBar.swift
//  Forge
//
//  The custom floating "dock" — a frosted-glass capsule with icon + label items and a
//  rounded "bubble" that slides behind the active tab (Reddit/Apple style). Used as the
//  app's real navigation (see ContentView); content scrolls behind it so the glass reads.
//

import SwiftUI

struct ForgeTabBar: View {
    @Binding var selection: SceneState.Tab
    @Namespace private var bubble

    private struct Item {
        let tab: SceneState.Tab
        let title: String
        let icon: String
    }

    private let items: [Item] = [
        Item(tab: .feed,     title: "Home",     icon: "house.fill"),
        Item(tab: .history,  title: "History",  icon: "clock.fill"),
        Item(tab: .workout,  title: "Workout",  icon: "dumbbell.fill"),
        Item(tab: .settings, title: "Settings", icon: "gearshape.fill"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                Button {
                    guard selection != item.tab else { return }
                    Haptics.impact(.medium)
                    selection = item.tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.icon)
                            .font(.system(size: 19, weight: .medium))
                        Text(item.title)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(selection == item.tab ? .forgeLabel : .forgeSecondaryLabel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        ZStack {
                            if selection == item.tab {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.forgeLabel.opacity(0.15))
                                    .matchedGeometryEffect(id: "bubble", in: bubble)
                            }
                        }
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
        .animation(.snappy(duration: 0.3), value: selection)
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
