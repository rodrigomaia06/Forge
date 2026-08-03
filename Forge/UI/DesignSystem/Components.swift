//
//  Components.swift
//  Forge
//
//  Small reusable building blocks that read from the design tokens (Theme.swift), so the
//  same card and button treatment is defined once instead of inline at each call site.
//

import SwiftUI

/// The same one-physical-pixel separator used by a native List. Explicit cards use this instead of a
/// default Divider, whose proposed thickness can differ when it is hosted by a plain VStack.
struct ForgeListSeparator: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(Color(uiColor: .separator))
            .frame(height: 1 / displayScale)
            .accessibilityHidden(true)
    }
}

/// A non-List row that keeps the familiar trailing-edge swipe-to-delete interaction. Editable numeric
/// rows cannot live in `List` because recycling a focused UIKit field can wedge the main thread, but
/// removing List must not remove a user's quickest way to delete a set.
struct ForgeSwipeToDeleteRow<Content: View>: View {
    private let actionWidth: CGFloat = 76
    // The parent ScrollView begins recognising at roughly ten points. Waiting longer here lets a
    // vertical drag win first, even when it begins on text or a value field inside the card.
    private let horizontalActivationDistance: CGFloat = 24
    private let onDelete: () -> Void
    private let content: Content

    @State private var restingOffset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0
    @State private var isRemoving: Bool = false

    init(onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onDelete = onDelete
        self.content = content()
    }

    private var visibleOffset: CGFloat {
        min(0, max(-actionWidth, restingOffset + dragOffset))
    }

    private func performDelete() {
        // Let the focused field resign before its Core Data row is removed. The deletion runs on the
        // current main-loop turn so the row removal stays in the same animation transaction.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        // Shrink and fade the row first, then call the deletion after the animation completes.
        withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.86)) {
            // hide the exposed actions and animate collapse
            restingOffset = 0
            isRemoving = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            onDelete()
        }
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                performDelete()
            } label: {
                VStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: "trash.fill")
                    Text("Delete").font(.caption2.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .frame(width: actionWidth)
            .background(Color.forgeDestructive)
            .accessibilityLabel("Delete set")

            content
                .frame(maxWidth: .infinity)
                .background(Color.forgeSurface)
                .offset(x: visibleOffset)
        }
        .clipped()
        // When removing, scale & fade so the surrounding stack animates smoothly.
        .scaleEffect(x: 1, y: isRemoving ? 0.001 : 1, anchor: .top)
        .opacity(isRemoving ? 0 : 1)
        .allowsHitTesting(!isRemoving)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: horizontalActivationDistance)
                .updating($dragOffset) { value, state, _ in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    state = value.translation.width
                }
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    let projected = restingOffset + value.predictedEndTranslation.width
                    // A short damped spring follows the finger more naturally than an abrupt ease-out,
                    // while still settling quickly enough for repeated set entry.
                    withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.86)) {
                        restingOffset = projected < -(actionWidth / 2) ? -actionWidth : 0
                    }
                }
        )
        .accessibilityAction(named: "Delete set") {
            performDelete()
        }
    }
}

/// Shared geometry for the compact set controls used by both routine planning and live logging.
/// Keeping these values in one place prevents the two exercise-card tables from drifting apart.
enum ForgeSetRowStyle {
    static let numberBoxHeight: CGFloat = 36
    static let numberBoxCornerRadius: CGFloat = 8
    static let numberChipSize: CGFloat = 28
}

/// The numbered set chip shared by routine rows and live-workout rows. A routine and the workout made
/// from it should keep the same visual identity even though the live row has extra columns and a
/// completion control.
struct ForgeSetNumberChip: View {
    let index: Int
    var tint: Color? = nil
    var showsNote = false
    var showsPreviousValue = false

    var body: some View {
        let color = tint ?? .forgeSecondaryLabel
        Text("\(index)")
            .font(.forgeCaption)
            .foregroundColor(color)
            .frame(width: ForgeSetRowStyle.numberChipSize, height: ForgeSetRowStyle.numberChipSize)
            .background(Circle().fill(color.opacity(tint == nil ? 0.14 : 0.22)))
            .overlay(alignment: .topTrailing) {
                if showsNote {
                    Circle()
                        .fill(Color.forgeLabel)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().strokeBorder(Color.forgeBackground, lineWidth: 1))
                }
            }
            .overlay(alignment: .bottomLeading) {
                if showsPreviousValue {
                    Circle()
                        .fill(Color.forgeAccent)
                        .frame(width: 6, height: 6)
                        .overlay(Circle().strokeBorder(Color.forgeBackground, lineWidth: 1))
                }
            }
    }
}

private struct ForgeSetValueBoxModifier: ViewModifier {
    let width: CGFloat
    let invalid: Bool

    func body(content: Content) -> some View {
        content
            .frame(width: width, height: ForgeSetRowStyle.numberBoxHeight)
            .background(
                RoundedRectangle(cornerRadius: ForgeSetRowStyle.numberBoxCornerRadius, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ForgeSetRowStyle.numberBoxCornerRadius, style: .continuous)
                    .stroke(Color.forgeDestructive, lineWidth: invalid ? 2 : 0)
            )
    }
}

/// Filled accent button for a screen's primary action (e.g. "Start workout").
struct ForgePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.forgeHeadline)
            .foregroundColor(.forgeBackground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.Layout.minTapTarget)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .fill(Color.forgeAccent)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(Rectangle())
    }
}

extension View {
    /// The standard raised-surface card: a filled, rounded background used by tiles and rows.
    func forgeCard(radius: CGFloat = Theme.Radius.large) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.forgeSurface)
        )
    }

    /// The numeric box used inside both routine and live-workout set rows.
    func forgeSetValueBox(width: CGFloat, invalid: Bool = false) -> some View {
        modifier(ForgeSetValueBoxModifier(width: width, invalid: invalid))
    }
}

/// A text field with a clear (x) button that appears while it has content. Commits on end-edit and
/// when cleared, so callers can persist through the same closure.
struct ClearableTextField: View {
    let titleKey: String
    @Binding var text: String
    var onCommit: () -> Void = {}

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            TextField(titleKey, text: $text, onEditingChanged: { isEditing in
                if !isEditing { onCommit() }
            })
            if !text.isEmpty {
                Button {
                    text = ""
                    onCommit()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.forgeSecondaryLabel)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }
        }
    }
}
