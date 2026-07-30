//
//  RestTimerView.swift
//  Forge
//
//  Running: a large countdown with a native progress bar and a stepper to nudge the time. Choosing a
//  time: a native wheel picker and a Start button. Uses standard SwiftUI controls throughout.
//

import SwiftUI

struct RestTimerView: View {
    @EnvironmentObject var restTimerStore: RestTimerStore

    @ObservedObject private var refresher = Refresher()

    @State private var customTime: TimeInterval = 90

    // i.e. 8.1 and 8.9 should be displayed as 9
    private var roundedRemainingTime: TimeInterval? {
        restTimerStore.restTimerRemainingTime?.rounded(.up)
    }

    private var remainingFraction: Double {
        guard let duration = restTimerStore.restTimerDuration, duration > 0,
              let remaining = roundedRemainingTime else { return 0 }
        return max(0, min(1, remaining / duration))
    }

    private func startTimer(duration: TimeInterval) {
        Haptics.impact(.light)
        restTimerStore.restTimerStart = Date()
        restTimerStore.restTimerDuration = duration

        restTimerStore.recentRestTimes.removeAll { $0 == duration }
        restTimerStore.recentRestTimes.insert(duration, at: 0)
    }

    /// Adjust the running timer's total duration, which extends or shortens the remaining time.
    private func adjust(by delta: TimeInterval) {
        guard let duration = restTimerStore.restTimerDuration else { return }
        Haptics.impact(.light)
        let newDuration = duration + delta
        restTimerStore.restTimerDuration = newDuration > 0 ? newDuration : nil
    }

    // MARK: Running

    private var runningTimerView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer(minLength: 0)

            VStack(spacing: Theme.Spacing.m) {
                if let remaining = roundedRemainingTime {
                    Text(restTimerDurationFormatter.string(from: abs(remaining)) ?? "")
                        .font(.system(size: 64, weight: .light).monospacedDigit())
                        .foregroundColor(remaining < 0 ? .forgeDestructive : .forgeLabel)
                }
                ProgressView(value: remainingFraction)
                    .tint(.forgeAccent)
                    .padding(.horizontal, Theme.Spacing.xl)
            }

            Stepper(
                "Rest \(restTimerDurationFormatter.string(from: restTimerStore.restTimerDuration ?? 0) ?? "")",
                onIncrement: { adjust(by: 10) },
                onDecrement: { adjust(by: -10) }
            )
            .padding(.horizontal, Theme.Spacing.xl)

            Button("Skip rest", role: .destructive) {
                Haptics.warning()
                restTimerStore.restTimerStart = nil
                restTimerStore.restTimerDuration = nil
            }
            .tint(.forgeDestructive)

            Spacer(minLength: 0)
        }
        .padding()
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in self.refresher.refresh() }
    }

    // MARK: Choosing a time

    private var stoppedTimerView: some View {
        VStack(spacing: Theme.Spacing.l) {
            Picker("Rest time", selection: $customTime) {
                ForEach(restTimerCustomTimes, id: \.self) { time in
                    Text(restTimerDurationFormatter.string(from: time) ?? "").tag(time)
                }
            }
            .pickerStyle(.wheel)

            Button {
                startTimer(duration: customTime)
            } label: {
                Text("Start").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
        }
        .padding()
        .onAppear {
            // Default the wheel to the last rest time used, when it is one of the offered values.
            if let recent = restTimerStore.recentRestTimes.first, restTimerCustomTimes.contains(recent) {
                customTime = recent
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

#if DEBUG
struct RestTimerView_Previews: PreviewProvider {
    static var previews: some View {
        RestTimerView()
            .environmentObject(RestTimerStore.shared)
    }
}
#endif
