//
//  RestTimerView.swift
//  Forge
//
//  Running: a large countdown with a native progress bar and a stepper to nudge the time. Choosing a
//  time: a native wheel picker and a Start button. Uses standard SwiftUI controls throughout.
//

import SwiftUI
import Combine

struct RestTimerView: View {
    @EnvironmentObject var restTimerStore: RestTimerStore

    @ObservedObject private var refresher = Refresher()
    private static let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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

    private var isExpired: Bool {
        (roundedRemainingTime ?? 0) < 0
    }

    private func startTimer(duration: TimeInterval) {
        Haptics.impact(.light)
        restTimerStore.setTimer(start: Date(), duration: duration)

        restTimerStore.recentRestTimes.removeAll { $0 == duration }
        restTimerStore.recentRestTimes.insert(duration, at: 0)
    }

    /// Adjust the running timer's total duration, which extends or shortens the remaining time.
    private func adjust(by delta: TimeInterval) {
        guard let start = restTimerStore.restTimerStart,
              let duration = restTimerStore.restTimerDuration else { return }
        Haptics.impact(.light)
        guard let timer = RestTimerLogic.adjustedTimer(start: start, duration: duration, delta: delta) else {
            restTimerStore.cancel()
            return
        }
        restTimerStore.setTimer(start: timer.start, duration: timer.duration)
    }

    private func stopTimer() {
        Haptics.warning()
        restTimerStore.cancel()
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

            if isExpired {
                HStack(spacing: Theme.Spacing.m) {
                    Button { adjust(by: 30) } label: {
                        Text("+30s").frame(maxWidth: .infinity).frame(minHeight: 44).forgeGlassCapsule().glassOutline()
                    }
                    Button { adjust(by: 60) } label: {
                        Text("+1 min").frame(maxWidth: .infinity).frame(minHeight: 44).forgeGlassCapsule().glassOutline()
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.forgeLabel)
                .padding(.horizontal, Theme.Spacing.xl)
            } else {
                // Adjust only the current running countdown, not the saved rest time.
                HStack(spacing: Theme.Spacing.m) {
                    Button { adjust(by: -10) } label: {
                        Text("\u{2212}10s").frame(maxWidth: .infinity).frame(minHeight: 44).forgeGlassCapsule().glassOutline()
                    }
                    Button { adjust(by: 10) } label: {
                        Text("+10s").frame(maxWidth: .infinity).frame(minHeight: 44).forgeGlassCapsule().glassOutline()
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.forgeLabel)
                .padding(.horizontal, Theme.Spacing.xl)
            }

            Button("Stop timer", role: .destructive) {
                stopTimer()
            }
            .tint(.forgeDestructive)

            Spacer(minLength: 0)
        }
        .padding()
        .onReceive(Self.timer) { _ in self.refresher.refresh() }
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
                Text("Start")
                    .font(.forgeHeadline)
                    .foregroundColor(.forgeLabel)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .forgeGlassCapsule()
                    .glassOutline()
            }
            .buttonStyle(.plain)
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
