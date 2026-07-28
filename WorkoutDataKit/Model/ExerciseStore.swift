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

    @Published private(set) public var customExercises: [Exercise]

    public var exercises: [Exercise] {
        builtInExercises + customExercises
    }

    public var shownExercises: [Exercise] {
        exercises.filter { !isHidden(exercise: $0) }
    }

    public var hiddenExercises: [Exercise] {
        exercises.filter { isHidden(exercise: $0) }
    }

    /// Core Data context backing custom exercises. Custom exercises now live in the workout
    /// database (the CustomExercise entity), so a plain database export/import carries them.
    /// It's optional because some callers (tests, the v1 migration policy) don't need custom
    /// exercises; there the list is simply empty.
    private let context: NSManagedObjectContext?

    private let userDefaults: UserDefaults

    public init(builtInExercisesURL: URL = ExerciseStore.defaultBuiltInExercisesURL, context: NSManagedObjectContext? = nil, userDefaults: UserDefaults = UserDefaults.standard) {
        self.userDefaults = userDefaults
        self.context = context
        builtInExercises = Self.loadBuiltInExercises(builtInExercisesURL: builtInExercisesURL)
        customExercises = Self.loadCustomExercises(context: context)
        assert(!customExercises.contains { !$0.isCustom }, "Loaded custom exercise that is not custom.")
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

// MARK: - Hidden Exercises
extension ExerciseStore {
    public func show(exercise: Exercise) {
        assert(!exercise.isCustom, "Makes no sense to show custom exercise.")
        self.objectWillChange.send()
        userDefaults.hiddenExerciseUuids.removeAll { $0 == exercise.uuid }
    }

    public func hide(exercise: Exercise) {
        assert(!exercise.isCustom, "Makes no sense to hide custom exercise.")
        guard !isHidden(exercise: exercise) else { return }
        self.objectWillChange.send()
        userDefaults.hiddenExerciseUuids.append(exercise.uuid)
    }

    public func isHidden(exercise: Exercise) -> Bool {
        userDefaults.hiddenExerciseUuids.contains(exercise.uuid)
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
        Self.find(in: exercises, with: uuid)
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
            steps: [], tips: [], references: [], pdfPaths: []
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
