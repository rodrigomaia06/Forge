//
//  WorkoutRoutineSuperset.swift
//  WorkoutDataKit
//
//  The routine-side mirror of WorkoutSuperset: the same grouping expressed on a routine's exercises, so a
//  plan can define a superset and it carries into the workouts started from it. Routines are templates, so
//  there is no rest or completion behavior here, only the grouping, ordering, and A / B / C labels.
//

import CoreData

// MARK: - A single routine exercise's view of its superset

extension WorkoutRoutineExercise {
    /// True when this routine exercise belongs to a superset.
    public var isInSuperset: Bool { supersetUUID != nil }

    /// The routine exercises grouped with this one, in routine order, including self. This is the run of
    /// adjacent exercises sharing the same superset id. Just self when it is not in a superset.
    public var supersetPartners: [WorkoutRoutineExercise] {
        guard let uuid = supersetUUID,
              let all = workoutRoutine?.workoutRoutineExercises?.array as? [WorkoutRoutineExercise],
              let index = all.firstIndex(of: self) else { return [self] }
        var lower = index
        var upper = index
        while lower > 0, all[lower - 1].supersetUUID == uuid { lower -= 1 }
        while upper < all.count - 1, all[upper + 1].supersetUUID == uuid { upper += 1 }
        return Array(all[lower...upper])
    }

    /// Zero-based position within the superset, for an A / B / C label. Nil when not in a superset.
    public var supersetIndex: Int? {
        guard isInSuperset else { return nil }
        return supersetPartners.firstIndex(of: self)
    }

    /// The A / B / C label for this exercise's place in its superset, or nil when not in one.
    public var supersetLabel: String? {
        guard let index = supersetIndex else { return nil }
        return String(UnicodeScalar(UInt8(65 + min(index, 25))))
    }

    /// True when this is the last exercise in its superset.
    public var isLastInSuperset: Bool {
        guard isInSuperset else { return false }
        return supersetPartners.last == self
    }

    /// The note shared by the whole superset, stored on each member and kept equal. Nil when there is none
    /// or the exercise is not in a superset.
    public var supersetNote: String? {
        guard isInSuperset, let note = supersetComment, !note.isEmpty else { return nil }
        return note
    }

    /// Sets the superset's shared note on every member of the group. An empty note clears it.
    public func setSupersetNote(_ note: String?) {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = (trimmed?.isEmpty ?? true) ? nil : trimmed
        for partner in supersetPartners { partner.supersetComment = value }
    }
}

// MARK: - A routine's grouped layout and grouping operations

extension WorkoutRoutine {
    /// One entry in the routine's exercise layout: a lone exercise, or a superset of two or more.
    public enum ExerciseSlot: Identifiable {
        case single(WorkoutRoutineExercise)
        case superset(id: UUID, exercises: [WorkoutRoutineExercise])

        public var id: String {
            switch self {
            case .single(let exercise): return exercise.id
            // A superset always has at least two members, so first is present.
            case .superset(_, let exercises): return exercises[0].id
            }
        }

        public var exercises: [WorkoutRoutineExercise] {
            switch self {
            case .single(let exercise): return [exercise]
            case .superset(_, let exercises): return exercises
            }
        }
    }

    /// The routine's exercises grouped for display, the same way a workout groups its exercises.
    public var exerciseSlots: [ExerciseSlot] {
        let all = workoutRoutineExercises?.array as? [WorkoutRoutineExercise] ?? []
        var slots: [ExerciseSlot] = []
        var index = 0
        while index < all.count {
            let exercise = all[index]
            if let uuid = exercise.supersetUUID {
                var group = [exercise]
                var next = index + 1
                while next < all.count, all[next].supersetUUID == uuid {
                    group.append(all[next])
                    next += 1
                }
                slots.append(group.count >= 2 ? .superset(id: uuid, exercises: group) : .single(exercise))
                index = next
            } else {
                slots.append(.single(exercise))
                index += 1
            }
        }
        return slots
    }

    /// Groups the given routine exercises into one superset in the given order, placed contiguously where
    /// the earliest of them currently sits. Returns the new superset id, or nil for fewer than two.
    @discardableResult
    public func makeSuperset(from exercises: [WorkoutRoutineExercise]) -> UUID? {
        let members = exercises.filter { $0.workoutRoutine == self }
        guard members.count >= 2 else { return nil }
        let uuid = UUID()
        members.forEach { $0.supersetUUID = uuid }
        reorderContiguously(members)
        return uuid
    }

    /// Removes the superset grouping with the given id. The exercises stay where they are; the shared note
    /// is cleared with the group.
    public func ungroupSuperset(id: UUID) {
        (workoutRoutineExercises?.array as? [WorkoutRoutineExercise] ?? [])
            .filter { $0.supersetUUID == id }
            .forEach { $0.supersetUUID = nil; $0.supersetComment = nil }
    }

    /// Restores the superset invariant after a reorder or delete: every stored superset id marks a
    /// contiguous run of two or more, each with its own id. Mirrors Workout.normalizeSupersets().
    public func normalizeSupersets() {
        let all = workoutRoutineExercises?.array as? [WorkoutRoutineExercise] ?? []
        var seenIDs = Set<UUID>()
        var index = 0
        while index < all.count {
            guard let uuid = all[index].supersetUUID else { index += 1; continue }
            var end = index
            while end + 1 < all.count, all[end + 1].supersetUUID == uuid { end += 1 }
            let run = all[index...end]
            if run.count < 2 {
                run.forEach { $0.supersetUUID = nil; $0.supersetComment = nil }
            } else if seenIDs.contains(uuid) {
                let fresh = UUID()
                run.forEach { $0.supersetUUID = fresh }
                seenIDs.insert(fresh)
            } else {
                seenIDs.insert(uuid)
            }
            index = end + 1
        }
    }

    private func reorderContiguously(_ members: [WorkoutRoutineExercise]) {
        guard let all = workoutRoutineExercises?.array as? [WorkoutRoutineExercise] else { return }
        let memberIDs = Set(members.map { $0.objectID })
        guard let firstMemberIndex = all.firstIndex(where: { memberIDs.contains($0.objectID) }) else { return }
        let insertionIndex = all[0..<firstMemberIndex].filter { !memberIDs.contains($0.objectID) }.count
        var result = all.filter { !memberIDs.contains($0.objectID) }
        result.insert(contentsOf: members, at: insertionIndex)
        workoutRoutineExercises = NSOrderedSet(array: result)
    }
}
