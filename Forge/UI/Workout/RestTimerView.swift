//
//  RestTimerView.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 14.08.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI

struct RestTimerView: View {
    @EnvironmentObject var restTimerStore: RestTimerStore
    
    @ObservedObject private var refresher = Refresher()
    
    @State private var showCustomTimerSelector = false

    // i.e. 8.1 and 8.9 should be displayed as 9
    private var roundedRemainingTime: TimeInterval? {
        restTimerStore.restTimerRemainingTime?.rounded(.up)
    }
    
    private var remainingTimeInPercent: CGFloat {
        guard let duration = restTimerStore.restTimerDuration else { return 0 }
        guard let remainingTime = roundedRemainingTime else { return 0 }
        assert(duration > 0)
        return CGFloat(remainingTime / duration)
    }
    
    private var progressCircle: some View {
        ZStack {
            Circle()
                .stroke(Color(UIColor.systemFill), lineWidth: 8)
            Circle()
                .trim(from: 0, to: remainingTimeInPercent)
                .stroke(Color.accentColor, lineWidth: 8)
                // Animate only the progress change, not every layout pass (the old implicit
                // .animation(.default) made opening and adjusting the timer janky).
                .animation(.default, value: remainingTimeInPercent)
        }
        .rotationEffect(.degrees(-90))
//        .shadow(radius: 4)
    }
    
    private var timerProgress: some View {
        ZStack {
            progressCircle
                .frame(width: 240, height: 240)
            VStack {
                if let remainingTime = roundedRemainingTime {
                    Text(restTimerDurationFormatter.string(from: abs(remainingTime)) ?? "")
                        .font(Font.system(size: 48, weight: .light).monospacedDigit())
                        .foregroundColor(remainingTime < 0 ? .red : nil)
                }

                Text(restTimerDurationFormatter.string(from: restTimerStore.restTimerDuration ?? 0) ?? "")
                    .font(Font.subheadline.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private var runningTimerButtons: some View {
        HStack {
            CircleButton(action: {
                guard let duration = self.restTimerStore.restTimerDuration else { return }
                Haptics.impact(.light)
                let newDuration = duration - 10
                if newDuration > 0 {
                    self.restTimerStore.restTimerDuration = newDuration
                } else {
                    self.restTimerStore.restTimerDuration = nil
                }
            }) {
                Text("-10s")
            }

            CircleButton(action: {
                guard let duration = self.restTimerStore.restTimerDuration else { return }
                Haptics.impact(.light)
                self.restTimerStore.restTimerDuration = duration + 10
            }) {
                Text("+10s")
            }

            CircleButton(color: Color.red.opacity(0.9), action: {
                // Cancelling the timer is a discard, so a warning haptic rather than a light tap.
                Haptics.warning()
                self.restTimerStore.restTimerStart = nil
                self.restTimerStore.restTimerDuration = nil
            }) {
                Text("Cancel").fontWeight(.semibold).foregroundColor(.white)
            }
        }
    }
    
    private var runningTimerView: some View {
        VStack {
            timerProgress
                .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in self.refresher.refresh() }
            runningTimerButtons
                .padding()
        }
    }
    
    private func startTimer(duration: TimeInterval) {
        Haptics.impact(.light)
        restTimerStore.restTimerStart = Date()
        restTimerStore.restTimerDuration = duration
        
        restTimerStore.recentRestTimes.removeAll { $0 == duration }
        restTimerStore.recentRestTimes.insert(duration, at: 0)
    }
    
    private func timeTile(_ label: String, filled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.forgeValue)
                .foregroundColor(filled ? .forgeLabel : .forgeSecondaryLabel)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                        .fill(filled ? Color.forgeSurface : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                                .strokeBorder(Color.forgeSeparator, lineWidth: filled ? 0 : 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
    
    private static let defaultRestTimes: [TimeInterval] = [60, 90, 120, 150, 180]
    
    private var restTimes: [TimeInterval] {
        let recentRestTimes = restTimerStore.recentRestTimes
        if recentRestTimes.count >= Self.defaultRestTimes.count { return recentRestTimes }
        return Array((recentRestTimes + Self.defaultRestTimes.filter { !recentRestTimes.contains($0) }).prefix(Self.defaultRestTimes.count))
    }
    
    private var defaultTimerButtons: some View {
        let columns = [GridItem(.flexible(), spacing: Theme.Spacing.m), GridItem(.flexible(), spacing: Theme.Spacing.m)]
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            LazyVGrid(columns: columns, spacing: Theme.Spacing.m) {
                ForEach(restTimes, id: \.self) { time in
                    timeTile(restTimerDurationFormatter.string(from: time) ?? "") {
                        self.startTimer(duration: time)
                    }
                }
                timeTile("Other", filled: false) {
                    self.showCustomTimerSelector = true
                }
            }
            .padding(.horizontal)
            Spacer(minLength: 0)
        }
    }
    
    private var customTimerSelector: some View {
        VStack {
            List(restTimerCustomTimes, id: \.self) { time in
                Button(restTimerDurationFormatter.string(from: time)!) {
                    self.startTimer(duration: time)
                    self.showCustomTimerSelector = false
                }
            }
            Button("Back") {
                self.showCustomTimerSelector = false
            }
        }
    }

    private var stoppedTimerView: some View {
        Group {
            if showCustomTimerSelector {
                customTimerSelector
            } else {
                defaultTimerButtons
            }
        }
    }
    
    var body: some View {
        Group {
            if restTimerStore.restTimerRemainingTime != nil {
                runningTimerView
            } else {
                stoppedTimerView
            }
        }
    }
}

private struct CircleButton<Label>: View where Label: View {
    private let buttonSize: CGFloat = 80
    
    private let color: Color?
    private let action: () -> Void
    private let label: Label
    
    init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.init(color: nil, action: action, label: label)
    }
    
    init(color: Color?, action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.color = color
        self.action = action
        self.label = label()
    }
    
    var body: some View {
        Button(action: action) {
            label
                .frame(width: buttonSize, height: buttonSize)
                .background(Circle().foregroundColor(color ?? Color(UIColor.systemFill)))
        }
        .padding(4)
    }
}

#if DEBUG
struct RestTimerView_Previews: PreviewProvider {
    static var previews: some View {
//        if restTimerStore.restTimerRemainingTime == nil {
//            restTimerStore.restTimerStart = Date()
//            restTimerStore.restTimerDuration = 90
//        }
        return RestTimerView()
            .environmentObject(RestTimerStore.shared)
//            .previewDevice(PreviewDevice(rawValue: "iPad Pro (11-inch)"))
//            .previewDevice(PreviewDevice(rawValue: "iPhone Xs Max"))
//            .previewDevice(PreviewDevice(rawValue: "iPhone SE"))
    }
}
#endif
