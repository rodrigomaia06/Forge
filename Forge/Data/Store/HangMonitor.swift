//
//  HangMonitor.swift
//  Forge
//
//  Records when the main thread stops responding, and what the app was doing just before.
//
//  A freeze that only a force-quit clears leaves nothing behind: the process is killed, so there is no
//  crash report to read and no log that survives. This watches the main thread from a background queue
//  and writes a short record the moment it stops answering, so the next launch can say when the freeze
//  happened, how long it had lasted, and which interactions led up to it.
//
//  Records hold interaction names only, of the kind "set options opened" or "tab changed". Never
//  workout contents, values, exercise names, notes, or identifiers. Nothing is sent anywhere: the file
//  is local, and sharing it is the user's choice.
//

import Foundation
import UIKit
import os.log

final class HangMonitor {
    static let shared = HangMonitor()

    /// Below this a stall is a hitch, not a freeze, and is not worth a record.
    private static let hangThreshold: TimeInterval = 3
    private static let pingInterval: TimeInterval = 0.5
    // Long enough to retain several minutes of one-second timer checkpoints plus the interaction trail
    // that led to a freeze. Events are function names and lifecycle phases only, never workout data.
    private static let breadcrumbLimit = 300
    private static let reportLimit = 20

    private let queue = DispatchQueue(label: "com.rodrigomaia.forge.hang-monitor")
    private var timer: DispatchSourceTimer?

    private let lock = NSLock()
    /// Guarded by `lock`.
    private var lastResponse = Date()
    /// Guarded by `lock`.
    private var breadcrumbs: [String] = []
    /// Only touched on `queue`.
    private var alreadyReportedThisHang = false
    /// Only touched on `queue`. Monitoring pauses in the background, where the main thread is meant to
    /// stop; without this every backgrounding would be filed as a freeze.
    private var isActive = false

    private init() {}

    // MARK: - Lifecycle

    /// Block-based observers, so this stays a plain Swift class rather than an NSObject subclass just to
    /// satisfy #selector. Held so they can be removed, and so the results are not discarded.
    private var observers: [NSObjectProtocol] = []

    func start() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                // Coming back from the background, the gap since the last response is not a hang.
                Self.note("UIApplication.didBecomeActive")
                self?.becameActive()
            },
            center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Self.note("UIApplication.willResignActive")
                self?.queue.async { self?.isActive = false }
            },
            // Bracket the whole keyboard transition, including frame changes. The paired will/did events
            // distinguish a completed system transition from one that never returned to the run loop.
            center.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
                Self.note("keyboard will show")
            },
            center.addObserver(forName: UIResponder.keyboardDidShowNotification, object: nil, queue: .main) { _ in
                Self.note("keyboard did show")
            },
            center.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                Self.note("keyboard will hide")
            },
            center.addObserver(forName: UIResponder.keyboardDidHideNotification, object: nil, queue: .main) { _ in
                Self.note("keyboard did hide")
            },
            center.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { _ in
                Self.note("keyboard will change frame")
            },
            center.addObserver(forName: UIResponder.keyboardDidChangeFrameNotification, object: nil, queue: .main) { _ in
                Self.note("keyboard did change frame")
            },
        ]

        queue.async { [self] in
            guard timer == nil else { return }
            let source = DispatchSource.makeTimerSource(queue: queue)
            source.schedule(deadline: .now() + Self.pingInterval, repeating: Self.pingInterval)
            source.setEventHandler { [weak self] in self?.tick() }
            timer = source
            source.resume()
        }
        becameActive()
    }

    private func becameActive() {
        markResponsive()
        queue.async { [self] in
            isActive = true
            alreadyReportedThisHang = false
        }
    }

    // MARK: - Breadcrumbs

    /// Records an interaction, to be attached to the next freeze. Name the action, never its content:
    /// "set options opened", not which set or what is in it.
    static func note(_ event: String) {
        shared.lock.lock()
        defer { shared.lock.unlock() }
        shared.breadcrumbs.append("\(Self.clock.string(from: Date()))  \(event)")
        if shared.breadcrumbs.count > breadcrumbLimit {
            shared.breadcrumbs.removeFirst(shared.breadcrumbs.count - breadcrumbLimit)
        }
    }

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    // MARK: - Watching

    private func markResponsive() {
        lock.lock()
        lastResponse = Date()
        lock.unlock()
    }

    private func tick() {
        guard isActive else { return }

        lock.lock()
        let last = lastResponse
        lock.unlock()

        let stalled = Date().timeIntervalSince(last)
        if stalled >= Self.hangThreshold, !alreadyReportedThisHang {
            alreadyReportedThisHang = true
            record(stalledFor: stalled)
        }

        // The reply only lands once the main thread is free again, which is what makes the gap
        // measurable in the first place.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.markResponsive()
            self.queue.async { self.alreadyReportedThisHang = false }
        }
    }

    private func record(stalledFor duration: TimeInterval) {
        lock.lock()
        let trail = breadcrumbs
        let last = lastResponse
        lock.unlock()

        os_log("Main thread unresponsive for %.1fs", type: .error, duration)
        var reports = Self.loadReports()
        reports.append(FreezeReport(date: Date(), seconds: duration, lastResponse: last, breadcrumbs: trail))
        if reports.count > Self.reportLimit {
            reports.removeFirst(reports.count - Self.reportLimit)
        }
        Self.save(reports)
    }

    // MARK: - Storage

    private static var fileURL: URL? {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("freeze-reports.json")
    }

    static func loadReports() -> [FreezeReport] {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([FreezeReport].self, from: data)) ?? []
    }

    private static func save(_ reports: [FreezeReport]) {
        guard let url = fileURL, let data = try? JSONEncoder().encode(reports) else { return }
        // Readable after the first unlock, so a record written while the screen is locked still lands.
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func clearReports() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

/// One recorded freeze. Interaction names and timings only.
struct FreezeReport: Codable, Identifiable {
    let date: Date
    let seconds: TimeInterval
    /// The last moment the main thread answered a ping. The gap between the final breadcrumb and this
    /// says whether the app was idle before it hung or was already busy with something unrecorded.
    let lastResponse: Date?
    let breadcrumbs: [String]

    var id: Date { date }
}
