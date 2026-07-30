//
//  SwiftUISupport.swift
//  Iron
//
//  Created by Karim Abou Zeid on 18.09.20.
//  Copyright © 2020 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI

struct TextCaseNil: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 14.0, *) {
            content.textCase(nil)
        } else {
            content
        }
    }
}

extension View {
    @ViewBuilder
    func textCaseCompat_nil() -> some View {
        if #available(iOS 14.0, *) {
            textCase(nil)
        } else {
            self
        }
    }
}

extension View {
    @ViewBuilder
    func listStyleCompat_InsetGroupedListStyle() -> some View {
        if #available(iOS 16.0, *) {
            // Hide the system grouped background and use the dashboard canvas, so every screen shares
            // the same near-black instead of the system's pure-black grouped background. Dragging the
            // list down dismisses the keyboard everywhere these lists are used.
            listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .background(Color.forgeBackground.ignoresSafeArea())
        } else if #available(iOS 14.0, *) {
            listStyle(InsetGroupedListStyle())
        } else {
            listStyle(GroupedListStyle())
        }
    }
}

extension View {
    @ViewBuilder
    func redacted_compat() -> some View {
        if #available(iOS 14.0, *) {
            redacted(reason: .placeholder)
        }
    }
}

extension View {
    /// Applies a modifier to a view conditionally.
    ///
    /// - Parameters:
    ///   - condition: The condition to determine if the content should be applied.
    ///   - content: The modifier to apply to the view.
    /// - Returns: The modified view.
    @ViewBuilder func modifier<T: View>(
        if condition: @autoclosure () -> Bool,
        then content: (Self) -> T
    ) -> some View {
        if condition() {
            content(self)
        } else {
            self
        }
    }
    
    /// Applies a modifier to a view conditionally.
    ///
    /// - Parameters:
    ///   - condition: The condition to determine the content to be applied.
    ///   - trueContent: The modifier to apply to the view if the condition passes.
    ///   - falseContent: The modifier to apply to the view if the condition fails.
    /// - Returns: The modified view.
    @ViewBuilder func modifier<TrueContent: View, FalseContent: View>(
        if condition: @autoclosure () -> Bool,
        then trueContent: (Self) -> TrueContent,
        else falseContent: (Self) -> FalseContent
    ) -> some View {
        if condition() {
            trueContent(self)
        } else {
            falseContent(self)
        }
    }
}

extension View {
    /// A big greeting-style header matching the Home and Workout tabs: the navigation bar is hidden and
    /// the whole screen sits on the dashboard canvas, so History and Settings read the same as those
    /// tabs instead of a small inline title on a differently-black navigation bar. `trailing` holds any
    /// header actions (Edit, filter) that would otherwise live in the navigation bar.
    func forgeScreenTitle<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.forgeGreeting)
                    .foregroundColor(.forgeLabel)
                Spacer()
                trailing()
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.xxl)
            .padding(.bottom, Theme.Spacing.m)

            self
        }
        .background(Color.forgeBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

extension View {
    /// Circular translucent backing for a header icon button. Uses Liquid Glass on iOS 26 and a
    /// system material circle on earlier versions, so the plus reads as a native control on both.
    @ViewBuilder func forgeGlassCircle() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: Circle())
        } else {
            self.background(.ultraThinMaterial, in: Circle())
        }
    }

    /// Liquid Glass pill for a group of header actions (Edit, filter) that used to sit in the navigation
    /// bar and get the glass treatment for free. Falls back to a system material capsule below iOS 26.
    @ViewBuilder func forgeGlassCapsule() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
        }
    }

    /// A slightly stronger hairline on a glass capsule button, so its edge reads clearly on the dark
    /// canvas rather than blending in.
    func glassOutline() -> some View {
        overlay(Capsule().strokeBorder(Color.forgeLabel.opacity(0.18), lineWidth: 1))
    }
}

/// Shows a brief "Editable in Edit mode" hint when a read-only row is tapped, so it is clear the value is
/// changed through Edit rather than by tapping it. Apply to rows shown only outside edit mode (a title or
/// comment being browsed, recorded times), matching the stopwatch's hint on the live workout.
private struct EditModeHint: ViewModifier {
    @State private var showHint = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .overlay(alignment: .trailing) {
                if showHint {
                    Text("Editable in Edit mode")
                        .font(.caption2)
                        .foregroundColor(.forgeSecondaryLabel)
                        .padding(.horizontal, Theme.Spacing.s)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .onTapGesture {
                guard !showHint else { return }
                Haptics.impact(.light)
                withAnimation { showHint = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { showHint = false }
                }
            }
    }
}

extension View {
    /// Tapping the row briefly points the user to Edit. Use on rows that only become editable in edit mode.
    func editModeHint() -> some View {
        modifier(EditModeHint())
    }
}

/// Ends editing when the user taps outside a text field. A single recognizer on the key window with
/// cancelsTouchesInView = false, so buttons, rows, and fields still get their taps; the delegate skips
/// taps on a text field so tapping one focuses it instead of dismissing the keyboard.
final class KeyboardDismissInstaller: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissInstaller()
    private weak var installedWindow: UIWindow?

    func install() {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else { return }
        if installedWindow === window { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        tap.cancelsTouchesInView = false
        // Don't hold up the touch: buttons (Done, etc.) must fire on the first tap even while the
        // recognizer is deciding, not wait for it.
        tap.delaysTouchesEnded = false
        tap.delegate = self
        window.addGestureRecognizer(tap)
        installedWindow = window
    }

    @objc private func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            view = current.superview
        }
        return true
    }

    // Recognize alongside every other gesture. SwiftUI Buttons use their own recognizers; without this the
    // window tap can claim the first tap while the keyboard is up (dismissing it) and starve the button, so
    // it takes a second tap to act. Recognizing simultaneously lets the keyboard dismiss and the button fire
    // on the same tap. Safe because the recognizer never cancels touches and dismiss() is a no-op when
    // nothing is focused.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

extension View {
    /// Dismisses the keyboard when tapping outside a text field. Apply once at the root.
    func dismissesKeyboardOnBackgroundTap() -> some View {
        onAppear { KeyboardDismissInstaller.shared.install() }
    }

    /// A single "Done" above the keyboard that dismisses whatever field is focused (numbers or text).
    /// Apply once per screen, not per field, or several Done buttons stack up.
    func keyboardDoneToolbar() -> some View {
        // No keyboard toolbar button: the number pads are dismissed by scrolling the list (the lists use
        // scrollDismissesKeyboard) or tapping away. Kept as a modifier so call sites stay put if a button
        // is ever reintroduced.
        self
    }
}
