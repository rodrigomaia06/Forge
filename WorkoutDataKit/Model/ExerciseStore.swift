//
//  ExerciseStore.swift
//  Forge
//
//  Created by Karim Abou Zeid on 17.09.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import Foundation
import CoreData
import os.log

public class ExerciseStore: ObservableObject {
    public static var defaultBuiltInExercisesResourceURL: URL {
        Bundle(for: Self.self).bundleURL.appendingPathComponent("everkinetic-data")
    }

    public static var defaultBuiltInExercisesURL: URL {
        defaultBuiltInExercisesResourceURL.appendingPathComponent("exercises.json")
    }

    public let builtInExercises: [Exercise]

    @Published private(set) public var customExercises: [Exercise] {
        didSet { rebuildLists() }
    }

    // These four are stored rather than computed. `exercises` used to be `builtInExercises +
    // customExercises`, which allocated and copied the whole 217-entry catalog on every read, and
    // `shownExercises` ran isHidden over all of it. They are read from view bodies and from per-row
    // helpers at around fifty call sites, several of them once per exercise per render, so the
    // copying dominated the cost of drawing the dashboard and the live workout. The catalog only
    // changes when a custom exercise or a per-exercise setting changes, so it is rebuilt there.

    /// Every exercise, built-in and custom.
    public private(set) var exercises: [Exercise] = []

    /// Exercises the user has not hidden.
    public private(set) var shownExercises: [Exercise] = []

    /// Exercises the user has hidden.
    public private(set) var hiddenExercises: [Exercise] = []

    /// `exercises` indexed by UUID, for the lookups that happen per row.
    private var exercisesByUuid: [UUID: Exercise] = [:]

    /// Core Data context backing custom exercises. Custom exercises now live in the workout
    /// database (the CustomExercise entity), so a plain database export/import carries them.
    /// It's optional because some callers (tests, the v1 migration policy) don't need custom
    /// exercises; there the list is simply empty.
    private let context: NSManagedObjectContext?

    /// Cached per-exercise settings (rest time + hidden) keyed by exercise UUID, so the
    /// frequently-called isHidden/restTime reads don't fetch from Core Data per exercise.
    private var exerciseSettings: [UUID: (restTime: TimeInterval?, hidden: Bool)] {
        didSet { rebuildLists() }
    }

    public init(builtInExercisesURL: URL = ExerciseStore.defaultBuiltInExercisesURL, context: NSManagedObjectContext? = nil) {
        self.context = context
        builtInExercises = Self.loadBuiltInExercises(builtInExercisesURL: builtInExercisesURL)
        customExercises = Self.loadCustomExercises(context: context)
        exerciseSettings = Self.loadExerciseSettings(context: context)
        assert(!customExercises.contains { !$0.isCustom }, "Loaded custom exercise that is not custom.")
        // A property observer does not fire during init, so the first build is explicit.
        rebuildLists()
    }

    private func rebuildLists() {
        exercises = builtInExercises + customExercises
        exercisesByUuid = Dictionary(exercises.map { ($0.uuid, $0) }, uniquingKeysWith: { _, latest in latest })
        var shown = [Exercise]()
        var hidden = [Exercise]()
        for exercise in exercises {
            if exerciseSettings[exercise.uuid]?.hidden ?? false {
                hidden.append(exercise)
            } else {
                shown.append(exercise)
            }
        }
        shownExercises = shown
        hiddenExercises = hidden
    }

    private static func loadBuiltInExercises(builtInExercisesURL: URL?) -> [Exercise] {
        guard let builtInExercisesURL = builtInExercisesURL else { fatalError("Built in exercises URL invalid") }
        do {
            return try JSONDecoder().decode([Exercise].self, from: Data(contentsOf: builtInExercisesURL))
        } catch {
            fatalError("Error decoding built in exercises: \(error.localizedDescription)")
        }
    }
}

// MARK: - Per-exercise settings: hidden + rest time (Core Data backed)
extension ExerciseStore {
    public func show(exercise: Exercise) {
        assert(!exercise.isCustom, "Makes no sense to show custom exercise.")
        guard let context = context, let entity = settingsEntity(for: exercise.uuid, in: context, createIfNeeded: false) else { return }
        entity.isHidden = false
        saveSettings(context)
    }

    public func hide(exercise: Exercise) {
        assert(!exercise.isCustom, "Makes no sense to hide custom exercise.")
        guard !isHidden(exercise: exercise), let context = context else { return }
        settingsEntity(for: exercise.uuid, in: context, createIfNeeded: true)?.isHidden = true
        saveSettings(context)
    }

    public func isHidden(exercise: Exercise) -> Bool {
        exerciseSettings[exercise.uuid]?.hidden ?? false
    }

    /// Per-exercise rest time override (nil = use the default rest time).
    public func restTime(forExercise uuid: UUID) -> TimeInterval? {
        exerciseSettings[uuid]?.restTime ?? nil
    }

    public func setRestTime(_ time: TimeInterval?, forExercise uuid: UUID) {
        guard let context = context else { return }
        settingsEntity(for: uuid, in: context, createIfNeeded: true)?.restTime = time.map { NSNumber(value: $0) }
        saveSettings(context)
    }

    private func settingsEntity(for uuid: UUID, in context: NSManagedObjectContext, createIfNeeded: Bool) -> ExerciseSettings? {
        let request = ExerciseSettings.fetchRequest()
        request.predicate = NSPredicate(format: "exerciseUuid == %@", uuid as CVarArg)
        request.fetchLimit = 1
        if let existing = (try? context.fetch(request))?.first { return existing }
        guard createIfNeeded else { return nil }
        let entity = ExerciseSettings(context: context)
        entity.exerciseUuid = uuid
        return entity
    }

    private func saveSettings(_ context: NSManagedObjectContext) {
        objectWillChange.send()
        do {
            try context.save()
        } catch {
            os_log("Could not save exercise settings: %@", log: .migration, type: .error, error.localizedDescription)
            context.rollback()
        }
        exerciseSettings = Self.loadExerciseSettings(context: context)
    }

    fileprivate static func loadExerciseSettings(context: NSManagedObjectContext?) -> [UUID: (restTime: TimeInterval?, hidden: Bool)] {
        guard let context = context else { return [:] }
        let request = ExerciseSettings.fetchRequest()
        let entities = (try? context.fetch(request)) ?? []
        var result: [UUID: (restTime: TimeInterval?, hidden: Bool)] = [:]
        for entity in entities {
            guard let uuid = entity.exerciseUuid else { continue }
            result[uuid] = (entity.restTime?.doubleValue, entity.isHidden)
        }
        return result
    }
}

// MARK: - Split
extension ExerciseStore {
    public static func splitIntoMuscleGroups(exercises: [Exercise]) -> [ExerciseGroup] {
        var groups = [ExerciseGroup]()
        var nextIndex = 0
        let exercises = exercises.sorted { (a, b) -> Bool in
            a.muscleGroup < b.muscleGroup
        }
        while (exercises.count > nextIndex) {
            let groupName = exercises[nextIndex].muscleGroup
            var muscleGroup = exercises.filter({ (exercise) -> Bool in
                exercise.muscleGroup == groupName
            })

            nextIndex = exercises.firstIndex(where: { (exercise) -> Bool in
                exercise.uuid == muscleGroup.last!.uuid
            })! + 1

            // do this after nextIndex is set
            muscleGroup = muscleGroup.sorted(by: { (a, b) -> Bool in
                a.title < b.title
            })
            groups.append(ExerciseGroup(title: groupName, exercises: muscleGroup))
        }
        return groups
    }
}

// MARK: - Find
extension ExerciseStore {
    public func find(with uuid: UUID) -> Exercise? {
        exercisesByUuid[uuid]
    }

    public static func find(in exercises: [Exercise], with uuid: UUID?) -> Exercise? {
        guard let uuid = uuid else { return nil }
        return exercises.first { $0.uuid == uuid }
    }
}

// MARK: - Filter
extension ExerciseStore {
    private static func titleMatchesFilter(title: String, filter: String) -> Bool {
        for s in filter.split(separator: " ") {
            if !title.lowercased().contains(s) {
                return false
            }
        }
        return true
    }

    public static func filter(exercises: [Exercise], using filter: String) -> [Exercise] {
        let filter = filter.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !filter.isEmpty else { return exercises }

        return exercises.filter { exercise in
            for title in [exercise.title] + exercise.alias {
                if titleMatchesFilter(title: title, filter: filter) {
                    return true
                }
            }
            return false
        }
    }

    public static func filter(exerciseGroups: [ExerciseGroup], using filter: String) -> [ExerciseGroup] {
        exerciseGroups
            .map { ExerciseGroup(title: $0.title, exercises: Self.filter(exercises: $0.exercises, using: filter)) }
            .filter { !$0.exercises.isEmpty }
    }
}

// MARK: - Custom Exercises (Core Data backed)
extension ExerciseStore {
    public func createCustomExercise(title: String, description: String?, primaryMuscle: [String], secondaryMuscle: [String], type: Exercise.ExerciseType) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        guard !exercises.contains(where: { $0.title == title }) else { return }
        guard let context = context else { return }

        let entity = CustomExercise(context: context)
        entity.uuid = UUID()
        apply(title: title, description: description, primaryMuscle: primaryMuscle, secondaryMuscle: secondaryMuscle, type: type, to: entity)
        saveAndReload(context)
    }

    public func updateCustomExercise(with uuid: UUID, title: String, description: String?, primaryMuscle: [String], secondaryMuscle: [String], type: Exercise.ExerciseType) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        guard !exercises.contains(where: { $0.title == title && $0.uuid != uuid }) else { return }
        guard let context = context, let entity = customExerciseEntity(with: uuid, in: context) else { return }

        apply(title: title, description: description, primaryMuscle: primaryMuscle, secondaryMuscle: secondaryMuscle, type: type, to: entity)
        saveAndReload(context)
    }

    public func deleteCustomExercise(with uuid: UUID) {
        guard let context = context, let entity = customExerciseEntity(with: uuid, in: context) else { return }
        deleteRoutineExercises(with: uuid, in: context)
        context.delete(entity)
        saveAndReload(context)
    }

    private func apply(title: String, description: String?, primaryMuscle: [String], secondaryMuscle: [String], type: Exercise.ExerciseType, to entity: CustomExercise) {
        var description = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = description, d.isEmpty { description = nil }
        entity.title = title
        entity.exerciseDescription = description
        entity.primaryMusclesJSON = Self.encodeStrings(primaryMuscle)
        entity.secondaryMusclesJSON = Self.encodeStrings(secondaryMuscle)
        entity.equipmentJSON = Self.encodeStrings(type.equipment.map { [$0] } ?? [])
    }

    private func customExerciseEntity(with uuid: UUID, in context: NSManagedObjectContext) -> CustomExercise? {
        let request = CustomExercise.fetchRequest()
        request.predicate = NSPredicate(format: "uuid == %@", uuid as CVarArg)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }

    private func deleteRoutineExercises(with uuid: UUID, in context: NSManagedObjectContext) {
        let request: NSFetchRequest<WorkoutRoutineExercise> = WorkoutRoutineExercise.fetchRequest()
        request.predicate = NSPredicate(format: "\(#keyPath(WorkoutRoutineExercise.exerciseUuid)) == %@", uuid as CVarArg)
        guard let routineExercises = try? context.fetch(request) else { return }
        for routineExercise in routineExercises {
            let routine = routineExercise.workoutRoutine
            context.delete(routineExercise)
            routine?.removeFromWorkoutRoutineExercises(routineExercise)
            routine?.normalizeSupersets()
        }
    }

    private func saveAndReload(_ context: NSManagedObjectContext) {
        do {
            try context.save()
        } catch {
            os_log("Could not save custom exercise: %@", log: .migration, type: .error, error.localizedDescription)
            context.rollback()
        }
        customExercises = Self.loadCustomExercises(context: context)
    }

    fileprivate static func loadCustomExercises(context: NSManagedObjectContext?) -> [Exercise] {
        guard let context = context else { return [] }
        let request = CustomExercise.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        let entities = (try? context.fetch(request)) ?? []
        return entities.compactMap { exercise(from: $0) }
    }

    private static func exercise(from entity: CustomExercise) -> Exercise? {
        guard let uuid = entity.uuid else { return nil }
        return Exercise(
            uuid: uuid,
            everkineticId: Exercise.customEverkineticId,
            title: entity.title ?? "",
            alias: [],
            description: entity.exerciseDescription,
            primaryMuscle: decodeStrings(entity.primaryMusclesJSON),
            secondaryMuscle: decodeStrings(entity.secondaryMusclesJSON),
            equipment: decodeStrings(entity.equipmentJSON),
            steps: [], tips: [], references: []
        )
    }

    private static func decodeStrings(_ json: String?) -> [String] {
        guard let data = json?.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    private static func encodeStrings(_ strings: [String]) -> String {
        guard let data = try? JSONEncoder().encode(strings), let string = String(data: data, encoding: .utf8) else { return "[]" }
        return string
    }
}
