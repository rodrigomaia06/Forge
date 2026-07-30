//
//  WorkoutSuperset.swift
//  WorkoutDataKit
//
//  Supersets: two or more exercises performed together, alternating, resting only after the round.
//  A group is expressed as a shared supersetUUID on the member exercises rather than a container entity,
//  so it is a property of the exercises and historical records stay untouched. A group is the run of
//  adjacent exercises in the workout that share a superset id; the app keeps members contiguous.
//

import CoreData

// MARK: - A single exercise's view of its superset

extension WorkoutExercise {
    /// True when this exercise belongs to a superset.
    public var isInSuperset: Bool { supersetUUID != nil }

    /// The exercises performed together as this exercise's superset, in workout order, including self.
    /// This is the run of adjacent exercises sharing the same superset id, matching how the group is
    /// shown. Returns just self when the exercise is not in a superset.
    public var supersetPartners: [WorkoutExercise] {
        guard let uuid = supersetUUID,
              let all = workout?.workoutExercises?.array as? [WorkoutExercise],
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

    /// True when this is the last exercise in its superset round.
    public var isLastInSuperset: Bool {
        guard isInSuperset else { return false }
        return supersetPartners.last == self
    }

    /// Whether completing a set on this exercise should start the rest timer. Inside a superset, rest
    /// holds until the last exercise of the round, so only that exercise starts it.
    public var startsRestTimerOnSetCompletion: Bool {
        !isInSuperset || isLastInSuperset
    }

    /// Whether completing a set should reorder this exercise behind the last begun one. A superset keeps
    /// its exercises together and in order, so grouped exercises are never reordered on completion.
    public var reordersBehindLastBegunOnSetCompletion: Bool {
        !isInSuperset
    }
}

// MARK: - A workout's grouped layout and grouping operations

extension Workout {
    /// One entry in the workout's exercise layout: a lone exercise, or a superset of two or more.
    public enum ExerciseSlot: Identifiable {
        case single(WorkoutExercise)
        case superset(id: UUID, exercises: [WorkoutExercise])

        public var id: NSManagedObjectID {
            switch self {
            case .single(let exercise): return exercise.objectID
            // A superset always has at least two members, so first is present.
            case .superset(_, let exercises): return exercises[0].objectID
            }
        }

        public var exercises: [WorkoutExercise] {
            switch self {
            case .single(let exercise): return [exercise]
            case .superset(_, let exercises): return exercises
            }
        }
    }

    /// The exercises grouped for display: consecutive exercises sharing a superset id become one superset
    /// slot, everything else a single slot. A superset that has dropped to one member renders as a single
    /// (it should be normalized away first, but this degrades gracefully).
    public var exerciseSlots: [ExerciseSlot] {
        let all = workoutExercises?.array as? [WorkoutExercise] ?? []
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

    /// Groups the given exercises into one superset in the given order, placed contiguously where the
    /// earliest of them currently sits. Returns the new superset id, or nil for fewer than two exercises.
    @discardableResult
    public func makeSuperset(from exercises: [WorkoutExercise]) -> UUID? {
        let members = exercises.filter { $0.workout == self }
        guard members.count >= 2 else { return nil }
        let uuid = UUID()
        members.forEach { $0.supersetUUID = uuid }
        reorderContiguously(members)
        return uuid
    }

    /// Removes the superset grouping with the given id. The exercises stay where they are.
    public func ungroupSuperset(id: UUID) {
        (workoutExercises?.array as? [WorkoutExercise] ?? [])
            .filter { $0.supersetUUID == id }
            .forEach { $0.supersetUUID = nil }
    }

    /// Clears any superset that has fewer than two members, so a lone exercise never keeps a stale
    /// superset id (for example after an exercise is removed from a group). Call after removing exercises.
    public func normalizeSupersets() {
        let all = workoutExercises?.array as? [WorkoutExercise] ?? []
        let memberCounts = Dictionary(grouping: all.compactMap { $0.supersetUUID }, by: { $0 })
            .mapValues { $0.count }
        for exercise in all {
            if let uuid = exercise.supersetUUID, (memberCounts[uuid] ?? 0) < 2 {
                exercise.supersetUUID = nil
            }
        }
    }

    /// Places `members` contiguously at the position of the earliest member, keeping the given order among
    /// them and the relative order of everything else. The members already have their workout inverse set,
    /// so assigning the ordered set only reorders them (it does not add or remove membership).
    private func reorderContiguously(_ members: [WorkoutExercise]) {
        guard let all = workoutExercises?.array as? [WorkoutExercise] else { return }
        let memberIDs = Set(members.map { $0.objectID })
        guard let firstMemberIndex = all.firstIndex(where: { memberIDs.contains($0.objectID) }) else { return }
        let insertionIndex = all[0..<firstMemberIndex].filter { !memberIDs.contains($0.objectID) }.count
        var result = all.filter { !memberIDs.contains($0.objectID) }
        result.insert(contentsOf: members, at: insertionIndex)
        workoutExercises = NSOrderedSet(array: result)
    }
}
