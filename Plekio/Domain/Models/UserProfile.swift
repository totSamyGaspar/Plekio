//
//  UserProfile.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.09.2026.
//

import Foundation

// MARK: - UserProfile

/// Who the app is for, shown in the exported document's header. Kept in
/// UserDefaults, not SwiftData; `nonisolated` because the report is built off the main actor.
nonisolated struct UserProfile: Codable, Equatable {

    // MARK: - Properties

    var name: String = ""
    var birthDate: Date?
    var allergies: String = ""
    var conditions: String = ""

    /// Id of the avatar in ImageCache; the image itself is never stored in defaults.
    var avatarId: UUID?

    static let storageKey = SettingsKey.userProfile
    static let empty = UserProfile()

    var isEmpty: Bool { self == .empty }

    // MARK: - Age

    /// Nil without a birth date or when it is after `date`.
    func age(on date: Date, calendar: Calendar = .current) -> Int? {
        guard let birthDate, birthDate <= date else { return nil }
        return calendar.dateComponents([.year], from: birthDate, to: date).year
    }
}

// MARK: - Coding

/// Hand-written so every field uses `decodeIfPresent`: a newly added key must not
/// make saved profiles fail to decode. `nonisolated` so the witnesses aren't main-actor.
nonisolated extension UserProfile {

    enum CodingKeys: String, CodingKey {
        case name, birthDate, allergies, conditions, avatarId
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
        birthDate = try values.decodeIfPresent(Date.self, forKey: .birthDate)
        allergies = try values.decodeIfPresent(String.self, forKey: .allergies) ?? ""
        conditions = try values.decodeIfPresent(String.self, forKey: .conditions) ?? ""
        avatarId = try values.decodeIfPresent(UUID.self, forKey: .avatarId)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(name, forKey: .name)
        try values.encodeIfPresent(birthDate, forKey: .birthDate)
        try values.encode(allergies, forKey: .allergies)
        try values.encode(conditions, forKey: .conditions)
        try values.encodeIfPresent(avatarId, forKey: .avatarId)
    }
}

// MARK: - Storage

/// Carries the profile through `@AppStorage`. A separate type: making UserProfile
/// itself RawRepresentable would make its Codable recurse through `rawValue` forever.
nonisolated struct StoredProfile: RawRepresentable {

    var profile: UserProfile

    init(_ profile: UserProfile) { self.profile = profile }

    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return nil }
        profile = decoded
    }

    /// Empty on encoding failure, which decodes to nil so `@AppStorage` uses its default.
    var rawValue: String {
        guard let data = try? JSONEncoder().encode(profile),
              let json = String(data: data, encoding: .utf8)
        else { return "" }
        return json
    }
}

// MARK: - Loading

nonisolated extension UserProfile {

    /// For non-view code, via `SettingsStore.userProfile`. No `.standard` default,
    /// so previews and tests never read the real profile.
    static func current(in defaults: UserDefaults) -> UserProfile {
        defaults.string(forKey: storageKey)
            .flatMap(StoredProfile.init(rawValue:))?
            .profile ?? .empty
    }
}
