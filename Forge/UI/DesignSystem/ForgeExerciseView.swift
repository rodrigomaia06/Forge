//
//  ForgeExerciseView.swift
//  Forge
//
//  Restyled in-workout exercise screen (mock layout for review). Composes the exercise
//  header, a card of ForgeSetRows, and an add-set affordance on the design tokens.
//  Value-based so it renders in previews / CI screenshots; wired into the live screen
//  once the look is agreed.
//

import SwiftUI

struct ForgeExerciseView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            header
            setCard
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.forgeBackground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text("Bench Press").font(.title.bold()).foregroundColor(.forgeLabel)
            Text("Chest · Barbell").font(.forgeCaption).foregroundColor(.forgeSecondaryLabel)
        }
    }

    private var setCard: some View {
        VStack(spacing: 0) {
            row(ForgeSetRow(number: 1, type: .warmUp, value: "60 kg × 8", previous: "60 kg × 8", status: .done))
            divider
            row(ForgeSetRow(number: 1, value: "80 kg × 5", target: "5–8", previous: "77.5 kg × 5", rpe: 8, status: .done, isPR: true))
            divider
            row(ForgeSetRow(number: 2, value: "80 kg × 5", target: "5–8", previous: "77.5 kg × 5", status: .upNext))
            divider
            row(ForgeSetRow(number: 3, value: "80 kg × 5", target: "5–8", previous: "77.5 kg × 4", status: .pending))
            divider
            addSetRow
        }
        .background(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous).fill(Color.forgeSurface))
    }

    private func row<Content: View>(_ content: Content) -> some View {
        content.padding(.horizontal, Theme.Spacing.l)
    }

    private var divider: some View {
        Divider().padding(.leading, Theme.Spacing.l)
    }

    private var addSetRow: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: "plus.circle.fill")
            Text("Add set").font(.forgeValue)
            Spacer()
        }
        .foregroundColor(.forgeAccent)
        .padding(.horizontal, Theme.Spacing.l)
        .frame(minHeight: Theme.Layout.minTapTarget)
        .contentShape(Rectangle())
    }
}

#if DEBUG
struct ForgeExerciseView_Previews: PreviewProvider {
    static var previews: some View {
        ForgeExerciseView().previewLayout(.sizeThatFits)
    }
}
#endif
