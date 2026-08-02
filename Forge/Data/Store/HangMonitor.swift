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

    /// The only text the diagnostics file can store. Callers choose one fixed label; they cannot pass
    /// workout content, entered values, names, notes, attributes, or identifiers by mistake.
    struct Event: Sendable {
        fileprivate let name: String
        private init(_ name: String) { self.name = name }

        static let appDidBecomeActive = Event("UIApplication.didBecomeActive")
        static let appWillResignActive = Event("UIApplication.willResignActive")
        static let appMemoryWarning = Event("UIApplication.memoryWarning")
        static let sceneWillEnterForeground = Event("scene will enter foreground")
        static let sceneDidEnterBackground = Event("scene did enter background")
        static let keyboardWillShow = Event("keyboard will show")
        static let keyboardDidShow = Event("keyboard did show")
        static let keyboardWillHide = Event("keyboard will hide")
        static let keyboardDidHide = Event("keyboard did hide")
        static let keyboardWillChangeFrame = Event("keyboard will change frame")
        static let keyboardDidChangeFrame = Event("keyboard did change frame")
        static let tabChanged = Event("tab changed")
        static let contextSaveBegin = Event("NSManagedObjectContext.save begin")
        static let contextSaveEnd = Event("NSManagedObjectContext.save end")
        static let coreDataFanOutBegin = Event("core data fan-out begin")
        static let coreDataFanOutEnd = Event("core data fan-out end")
        static let restTimerStartSetterBegin = Event("RestTimerStore.start setter begin")
        static let restTimerStartSetterEnd = Event("RestTimerStore.start setter end")
        static let restTimerDurationSetterBegin = Event("RestTimerStore.duration setter begin")
        static let restTimerDurationSetterEnd = Event("RestTimerStore.duration setter end")
        static let restTimerUpdateSurfacesBegin = Event("RestTimerStore.updateSurfaces begin")
        static let restTimerUpdateSurfacesEnd = Event("RestTimerStore.updateSurfaces end")
        static let numberFieldMakeBegin = Event("NumberField.makeUIView begin")
        static let numberFieldMakeEnd = Event("NumberField.makeUIView end")
        static let numberFieldFocusedUpdateBegin = Event("NumberField.updateUIView focused begin")
        static let numberFieldFocusedUpdateEnd = Event("NumberField.updateUIView focused end")
        static let numberFieldDismantleBegin = Event("NumberField.dismantleUIView begin")
        static let numberFieldDismantleEnd = Event("NumberField.dismantleUIView end")
        static let numberFieldDismantleResignBegin = Event("NumberField.dismantleUIView resign begin")
        static let numberFieldDismantleResignEnd = Event("NumberField.dismantleUIView resign end")
        static let numberFieldEditingChangedBegin = Event("NumberField.editingChanged begin")
        static let numberFieldEditingChangedEnd = Event("NumberField.editingChanged end")
        static let numberFieldDidBeginEditingBegin = Event("NumberField.didBeginEditing begin")
        static let numberFieldDidBeginEditingEnd = Event("NumberField.didBeginEditing end")
        static let numberFieldDidEndEditingBegin = Event("NumberField.didEndEditing begin")
        static let numberFieldDidEndEditingEnd = Event("NumberField.didEndEditing end")
        static let valueFieldFocused = Event("value field focused")
        static let valueFieldEndedEditing = Event("value field ended editing")
        static let valueFieldCommitFinished = Event("value field commit finished")
        static let keyboardDoneTapped = Event("keyboard done tapped")
        static let liveWorkoutRendered = Event("live workout rendered")
        static let liveWorkoutAppeared = Event("live workout appeared")
        static let liveWorkoutDisappeared = Event("live workout disappeared")
        static let liveWorkoutScrollAppeared = Event("live workout scroll appeared")
        static let liveWorkoutScrollDisappeared = Event("live workout scroll disappeared")
        static let currentWorkoutHeaderBuilt = Event("CurrentWorkoutView.header build")
        static let currentWorkoutListBuilt = Event("CurrentWorkoutView.list build")
        static let workoutEditModeToggled = Event("workout edit mode toggled")
        static let workoutSheetRequested = Event("workout sheet requested")
        static let workoutSheetPresented = Event("workout sheet presented")
        static let workoutSheetDismissed = Event("workout sheet dismissed")
        static let addExerciseSheetOpened = Event("add exercise sheet opened")
        static let exerciseCardBuilt = Event("exercise card built")
        static let exerciseCardAppeared = Event("exercise card appeared")
        static let exerciseCardDisappeared = Event("exercise card disappeared")
        static let setRowAppeared = Event("set row appeared")
        static let setRowDisappeared = Event("set row disappeared")
        static let exerciseNoteOpened = Event("exercise note opened")
        static let previousSessionsOpened = Event("previous sessions opened")
        static let setOptionsOpened = Event("set options opened")
        static let setCompletionToggled = Event("set completion toggled")
        static let completeSetBegin = Event("WorkoutExercise.completeSet begin")
        static let completeSetEnd = Event("WorkoutExercise.completeSet end")
        static let restTimerUpdateBegin = Event("WorkoutExercise.restTimer update begin")
        static let restTimerUpdateEnd = Event("WorkoutExercise.restTimer update end")
        static let attemptCompleteBegin = Event("ActiveSetRow.attemptComplete begin")
        static let attemptCompleteEnd = Event("ActiveSetRow.attemptComplete end")
        static let completeRefused = Event("complete refused")
        static let weightCommitted = Event("weight committed")
        static let repsCommitted = Event("reps committed")
        static let timerBody = Event("TimerBannerView.body")
        static let timerTickBegin = Event("TimerBannerView.tick begin")
        static let timerTickEnd = Event("TimerBannerView.tick end")
    }

    /// Below this a stall is a hitch, not a freeze, and is not worth a record.
    private static let hangThreshold: TimeInterval = 3
    private static let pingInterval: TimeInterval = 0.5
    // Long enough to retain several minutes of one-second timer checkpoints plus the interaction trail
    // that led to a freeze. Events are function names and lifecycle phases only, never workout data.
    private static let breadcrumbLimit = 600
    private static let reportLimit = 30
    /// While one permanent freeze continues, refresh the saved duration at this cadence. This keeps a
    /// force-quit report from always saying only 3.0 seconds when the app was blocked much longer.
    private static let reportRefreshInterval: TimeInterval = 1

    private let queue = DispatchQueue(label: "com.rodrigomaia.forge.hang-monitor")
    private var timer: DispatchSourceTimer?

    private let lock = NSLock()
    /// Guarded by `lock`.
    private var lastResponse = Date()
    /// Guarded by `lock`.
    private var breadcrumbs: [String] = []
    /// Only touched on `queue`.
    private var alreadyReportedThisHang = false
    /// Only touched on `queue`. Stable identity for the report refreshed while the same freeze continues.
    private var activeReportDate: Date?
    /// Only touched on `queue`.
    private var lastPersistedStall: TimeInterval = 0
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
                Self.note(.appDidBecomeActive)
                self?.becameActive()
            },
            center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Self.note(.appWillResignActive)
                self?.queue.async { self?.isActive = false }
            },
            // Bracket the whole keyboard transition, including frame changes. The paired will/did events
            // distinguish a completed system transition from one that never returned to the run loop.
            center.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
                Self.note(.keyboardWillShow)
            },
            center.addObserver(forName: UIResponder.keyboardDidShowNotification, object: nil, queue: .main) { _ in
                Self.note(.keyboardDidShow)
            },
            center.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                Self.note(.keyboardWillHide)
            },
            center.addObserver(forName: UIResponder.keyboardDidHideNotification, object: nil, queue: .main) { _ in
                Self.note(.keyboardDidHide)
            },
            center.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { _ in
                Self.note(.keyboardWillChangeFrame)
            },
            center.addObserver(forName: UIResponder.keyboardDidChangeFrameNotification, object: nil, queue: .main) { _ in
                Self.note(.keyboardDidChangeFrame)
            },
            center.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { _ in
                Self.note(.appMemoryWarning)
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
            activeReportDate = nil
            lastPersistedStall = 0
        }
    }

    // MARK: - Breadcrumbs

    /// Records an interaction, to be attached to the next freeze. Name the action, never its content:
    /// "set options opened", not which set or what is in it.
    static func note(_ event: Event) {
        shared.lock.lock()
        defer { shared.lock.unlock() }
        shared.breadcrumbs.append("\(Self.clock.string(from: Date()))  \(event.name)")
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
        if stalled >= Self.hangThreshold {
            if !alreadyReportedThisHang {
                alreadyReportedThisHang = true
                activeReportDate = Date()
                lastPersistedStall = 0
            }
            if stalled - lastPersistedStall >= Self.reportRefreshInterval,
               let reportDate = activeReportDate {
                lastPersistedStall = stalled
                record(stalledFor: stalled, reportDate: reportDate)
            }
        }

        // The reply only lands once the main thread is free again, which is what makes the gap
        // measurable in the first place.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.markResponsive()
            self.queue.async {
                self.alreadyReportedThisHang = false
                self.activeReportDate = nil
                self.lastPersistedStall = 0
            }
        }
    }

    private func record(stalledFor duration: TimeInterval, reportDate: Date) {
        lock.lock()
        let trail = breadcrumbs
        let last = lastResponse
        lock.unlock()

        os_log("Main thread unresponsive for %.1fs", type: .error, duration)
        var reports = Self.loadReports()
        let report = FreezeReport(date: reportDate, seconds: duration, lastResponse: last, breadcrumbs: trail)
        if let index = reports.firstIndex(where: { $0.id == reportDate }) {
            reports[index] = report
        } else {
            reports.append(report)
        }
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
