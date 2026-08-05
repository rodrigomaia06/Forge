//
//  RestTimerLogic.swift
//  Forge
//

import Foundation

enum RestTimerLogic {
    static func adjustedTimer(
        start: Date,
        duration: TimeInterval,
        delta: TimeInterval,
        now: Date = Date()
    ) -> (start: Date, duration: TimeInterval)? {
        let end = start.addingTimeInterval(duration)
        let remaining = end.timeIntervalSince(now)
        if remaining < 0 {
            guard delta > 0 else { return nil }
            return (now, delta)
        }

        let newDuration = duration + delta
        guard newDuration > 0 else { return nil }
        return (start, newDuration)
    }
}
