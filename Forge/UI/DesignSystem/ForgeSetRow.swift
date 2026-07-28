//
//  ForgeSetRow.swift
//  Forge
//
//  Restyled in-workout set row. Value-based (no Core Data) so it renders in previews
//  and CI screenshots and stays decoupled; the live screen maps a WorkoutSet onto it.
//
//  Improvements over the current row:
//   - Previous-session performance shown inline ("last 77.5 kg × 5") — Priority 1.
//   - Clear leading status (done / up-next / pending) with a forgiving tap target.
//   - Tokenised type/RPE/PR treatments; calm, scannable, one glance between sets.
//

import SwiftUI

struct ForgeSetRow: View {
    enum Status { case pending, upNext, done }

    enum SetType {
        case normal, warmUp, dropSet, failure
        var letter: String? {
            switch self {
            case .normal: return nil
            case .warmUp: return "W"
            case .dropSet: return "D"
            case .failure: return "F"
            }
        }
        var color: Color {
            switch self {
            case .normal: return .forgeSecondaryLabel
            case .warmUp: return .forgeWarning
            case .dropSet: return .forgeAccent
            case .failure: return .forgeDestructive
            }
        }
    }

    let number: Int
    var type: SetType = .normal
    /// Preformatted primary value, e.g. "80 kg × 5".
    let value: String
    /// Optional target, e.g. "8–12".
    var target: String? = nil
    /// Previous session's performance for this set, e.g. "77.5 kg × 5".
    var previous: String? = nil
    var rpe: Double? = nil
    var status: Status = .pending
    var isPR: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            statusIcon
                .frame(width: 24)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    Text(value)
                        .font(.forgeValue)
                        // The active (up-next) and completed sets read at full contrast; only
                        // not-yet-reached sets are muted, so the current set stands out at a glance.
                        .foregroundColor(status == .pending ? .forgeSecondaryLabel : .forgeLabel)
                    if let target {
                        Text(target)
                            .font(.forgeCaption)
                            .foregroundColor(.forgeSecondaryLabel)
                    }
                }
                if let previous {
                    Text("last \(previous)")
                        .font(.forgeCaption)
                        .foregroundColor(.forgeSecondaryLabel)
                }
            }

            Spacer(minLength: Theme.Spacing.s)

            if let rpe { rpePill(rpe) }
            if isPR {
                Image(systemName: "trophy.fill")
                    .font(.caption)
                    .foregroundColor(.forgeWarning)
                    .accessibilityLabel("Personal record")
            }
            numberBadge
        }
        .padding(.vertical, Theme.Spacing.s)
        .frame(minHeight: Theme.Layout.minTapTarget)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var statusIcon: some View {
        switch status {
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundColor(.forgeSuccess)
        case .upNext:
            Image(systemName: "chevron.right.circle.fill").foregroundColor(.forgeAccent)
        case .pending:
            Image(systemName: "circle").foregroundColor(.forgeSeparator)
        }
    }

    private var numberBadge: some View {
        ZStack {
            Circle().fill(Color.forgeBackground)
            if let letter = type.letter {
                Text(letter).font(.caption.weight(.semibold)).foregroundColor(type.color)
            } else {
                Text("\(number)").font(.forgeCaption.monospacedDigit()).foregroundColor(.forgeSecondaryLabel)
            }
        }
        .frame(width: 26, height: 26)
    }

    private func rpePill(_ rpe: Double) -> some View {
        Text("RPE \(rpe.formatted(.number.precision(.fractionLength(0...1))))")
            .font(.caption)
            .foregroundColor(.forgeSecondaryLabel)
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xxs)
            .background(
                Capsule().stroke(Color.forgeSeparator)
            )
    }
}

// A gallery of representative states, used for previews and CI screenshots.
struct ForgeSetRowGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Set rows").font(.forgeHeadline).foregroundColor(.forgeSecondaryLabel)
                .padding(.bottom, Theme.Spacing.s)
            Group {
                ForgeSetRow(number: 1, type: .warmUp, value: "60 kg × 8", previous: "60 kg × 8", status: .done)
                Divider()
                ForgeSetRow(number: 1, value: "80 kg × 5", target: "5–8", previous: "77.5 kg × 5", rpe: 8, status: .done, isPR: true)
                Divider()
                ForgeSetRow(number: 2, value: "80 kg × 5", target: "5–8", previous: "77.5 kg × 5", status: .upNext)
                Divider()
                ForgeSetRow(number: 3, value: "80 kg × 5", target: "5–8", previous: "77.5 kg × 4", status: .pending)
                Divider()
                ForgeSetRow(number: 4, type: .dropSet, value: "60 kg × 9", previous: "57.5 kg × 10", rpe: 10, status: .pending)
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.forgeSurface)
    }
}

#if DEBUG
struct ForgeSetRow_Previews: PreviewProvider {
    static var previews: some View {
        ForgeSetRowGallery().previewLayout(.sizeThatFits)
    }
}
#endif
