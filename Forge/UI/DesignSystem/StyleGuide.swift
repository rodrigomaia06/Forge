//
//  StyleGuide.swift
//  Forge
//
//  A visual catalogue of the design tokens. Rendered to a PNG in CI (see
//  IronTests/ScreenshotTests) so the design language can be reviewed without a Mac,
//  and grows into a component gallery as the UI overhaul proceeds.
//

import SwiftUI

struct StyleGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Text("Forge — Style Guide")
                .font(.largeTitle.bold())

            colours
            typography
            metrics
            radius
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.forgeBackground)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text(title).font(.forgeHeadline).foregroundColor(.forgeSecondaryLabel)
            content()
        }
    }

    private var colours: some View {
        section("Colours") {
            VStack(spacing: Theme.Spacing.s) {
                swatch("Background", .forgeBackground)
                swatch("Surface", .forgeSurface)
                swatch("Accent", .forgeAccent)
                swatch("Success", .forgeSuccess)
                swatch("Warning", .forgeWarning)
                swatch("Destructive", .forgeDestructive)
            }
        }
    }

    private func swatch(_ name: String, _ color: Color) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .fill(color)
                .frame(width: 56, height: 32)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Color.forgeSeparator))
            Text(name).font(.forgeValue)
            Spacer()
        }
    }

    private var typography: some View {
        section("Typography") {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("100.0 kg × 5").font(.forgeMetric).foregroundColor(.forgeLabel)
                Text("Bench Press").font(.forgeHeadline)
                Text("Working set").font(.forgeValue).foregroundColor(.forgeLabel)
                Text("Last session · 3 days ago").font(.forgeCaption).foregroundColor(.forgeSecondaryLabel)
            }
        }
    }

    private var metrics: some View {
        section("Spacing scale") {
            HStack(alignment: .bottom, spacing: Theme.Spacing.s) {
                spacingBar("xs", Theme.Spacing.xs)
                spacingBar("s", Theme.Spacing.s)
                spacingBar("m", Theme.Spacing.m)
                spacingBar("l", Theme.Spacing.l)
                spacingBar("xl", Theme.Spacing.xl)
                spacingBar("xxl", Theme.Spacing.xxl)
            }
        }
    }

    private func spacingBar(_ name: String, _ value: CGFloat) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Rectangle().fill(Color.forgeAccent).frame(width: value, height: value)
            Text(name).font(.caption2).foregroundColor(.forgeSecondaryLabel)
        }
    }

    private var radius: some View {
        section("Corner radius") {
            HStack(spacing: Theme.Spacing.m) {
                radiusTile("small", Theme.Radius.small)
                radiusTile("medium", Theme.Radius.medium)
                radiusTile("large", Theme.Radius.large)
            }
        }
    }

    private func radiusTile(_ name: String, _ value: CGFloat) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            RoundedRectangle(cornerRadius: value)
                .fill(Color.forgeSurface)
                .frame(width: 72, height: 48)
                .overlay(RoundedRectangle(cornerRadius: value).stroke(Color.forgeSeparator))
            Text(name).font(.caption2).foregroundColor(.forgeSecondaryLabel)
        }
    }
}

#if DEBUG
struct StyleGuide_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView { StyleGuide() }
    }
}
#endif
