//
//  WorkoutPlan.swift
//  WorkoutDataKit
//
//  Created by Karim Abou Zeid on 21.12.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import CoreData

extension WorkoutRoutineSet {
    // WorkoutRoutineSet already conforms to Identifiable via Core Data's generated properties.
    /// Identity for SwiftUI, from the uuid rather than the objectID.
    ///
    /// A newly inserted object has a temporary objectID that Core Data replaces with a permanent one the
    /// next time the context saves. Keyed on that, every save gave a set or exercise created during the
    /// workout a brand new identity: SwiftUI tore the row down and built a fresh one, and a text field
    /// being edited inside it was destroyed while it was still first responder. That leaves the keyboard
    /// up with nothing behind it. The uuid is assigned at creation and never changes.
    public var id: String { uuid?.uuidString ?? objectID.uriRepresentation().absoluteString }
}


public class WorkoutRoutineSet: NSManagedObject, Codable {
    public static let supportedTags = [WorkoutSetTag.warmUp, .dropSet, .failure, .backOff]
    
    public class func create(context: NSManagedObjectContext) -> WorkoutRoutineSet {
        let workoutRoutineSet = WorkoutRoutineSet(context: context)
        workoutRoutineSet.uuid = UUID()
        return workoutRoutineSet
    }
    
    // MARK: Normalized properties
    
    public var minRepetitionsValue: Int16? {
        get {
            minRepetitions?.int16Value
        }
        set {
            minRepetitions = newValue as NSNumber?
        }
    }
    
    public var maxRepetitionsValue: Int16? {
        get {
            maxRepetitions?.int16Value
        }
        set {
            maxRepetitions = newValue as NSNumber?
        }
    }
    
    public var tagValue: WorkoutSetTag? {
        get {
            guard let tag = WorkoutSetTag(rawValue: self.tag ?? "") else { return nil }
            guard Self.supportedTags.contains(tag) else { return nil }
            return tag
        }
        set {
            if let tag = newValue, !Self.supportedTags.contains(tag) { return }
            tag = newValue?.rawValue
        }
    }
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case uuid
        case minRepetitions
        case maxRepetitions
        case weight
        case rpe
        case tag
        case comment
    }
    
    required convenience public init(from decoder: Decoder) throws {
        guard let contextKey = CodingUserInfoKey.managedObjectContextKey,
            let context = decoder.userInfo[contextKey] as? NSManagedObjectContext,
            let entity = NSEntityDescription.entity(forEntityName: "WorkoutRoutineSet", in: context)
            else {
            throw CodingUserInfoKey.DecodingError.managedObjectContextMissing
        }
        self.init(entity: entity, insertInto: context)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decodeIfPresent(UUID.self, forKey: .uuid) ?? UUID() // make sure we always have an UUID
        minRepetitionsValue = try container.decodeIfPresent(Int16.self, forKey: .minRepetitions)
        maxRepetitionsValue = try container.decodeIfPresent(Int16.self, forKey: .maxRepetitions)
        tagValue = WorkoutSetTag(rawValue: try container.decodeIfPresent(String.self, forKey: .tag) ?? "")
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid ?? UUID(), forKey: .uuid)
        try container.encodeIfPresent(minRepetitionsValue, forKey: .minRepetitions)
        try container.encodeIfPresent(maxRepetitionsValue, forKey: .maxRepetitions)
        try container.encodeIfPresent(tagValue?.rawValue, forKey: .tag)
        try container.encodeIfPresent(comment, forKey: .comment)
    }
}
