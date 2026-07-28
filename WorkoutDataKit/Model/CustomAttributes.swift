//
//  CustomAttributes.swift
//  WorkoutDataKit
//
//  User-defined key/value fields on a workout or routine (for example location or mood), stored as
//  a JSON string in the additive customAttributesJSON attribute so old stores migrate lightly.
//

import Foundation

enum CustomAttributesCoding {
    static func decode(_ json: String?) -> [String: String] {
        guard let json = json,
              let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return dict
    }

    static func encode(_ dict: [String: String]) -> String? {
        guard !dict.isEmpty, let data = try? JSONEncoder().encode(dict) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

public extension Workout {
    var customAttributes: [String: String] {
        get { CustomAttributesCoding.decode(customAttributesJSON) }
        set { customAttributesJSON = CustomAttributesCoding.encode(newValue) }
    }
}

public extension WorkoutRoutine {
    var customAttributes: [String: String] {
        get { CustomAttributesCoding.decode(customAttributesJSON) }
        set { customAttributesJSON = CustomAttributesCoding.encode(newValue) }
    }
}
