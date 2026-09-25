//
//  UserProfile.swift
//  Plekio
//

import Foundation

/// Who the app is for, for the header of an exported document.
///
/// Not a `@Model` like its neighbours here: there is exactly one of these, it
/// has no relationships and nothing queries it. A row in the store would cost a
/// schema migration and an "exactly one" invariant to police, and give nothing
/// back.
///
/// `nonisolated` because the report is built off the main actor.
nonisolated struct UserProfile: Codable, Equatable {

    var name: String = ""
    var birthDate: Date?
    var allergies: String = ""
    var conditions: String = ""

    /// The avatar lives in `ImageCache` with every other photo; only its id is
    /// kept here. An image inlined into the defaults would be read into memory
    /// at every launch.
    var avatarId: UUID?

    static let storageKey = SettingsKey.userProfile
    static let empty = UserProfile()

    var isEmpty: Bool { self == .empty }

    /// Derived from the stored date rather than kept as a number, which would be
    /// wrong within a year of being entered.
    func age(on date: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let birthDate, birthDate <= date else { return nil }
        return calendar.dateComponents([.year], from: birthDate, to: date).year
    }
}

// MARK: - Coding

/// Written out by hand for one reason: `decodeIfPresent` everywhere.
///
/// This profile is on disk between releases of the app. When a field is added
/// later, the JSON already saved on someone's phone has no key for it, and the
/// synthesised decoder would throw on the whole profile rather than leave that
/// one field empty. Everything the user typed would silently vanish.
///
/// `nonisolated` on the extension, not on the type alone: with MainActor as the
/// default isolation an unannotated extension lands on the main actor, and a
/// main-actor witness cannot satisfy a nonisolated protocol requirement.
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

/// Carries the profile through `@AppStorage`, which stores strings.
///
/// The wrapper is `RawRepresentable` and the profile deliberately is not. The
/// standard library defines both coding and equality for `RawRepresentable`
/// types in terms of `rawValue`, and those definitions win over what the
/// compiler would otherwise synthesise. A profile that were both would encode
/// by asking for its own `rawValue` — which encodes it again, without end — and
/// compare as whatever string came out. Two roles, two types: the conflict
/// cannot arise instead of being worked around.
nonisolated struct StoredProfile: RawRepresentable {

    var profile: UserProfile

    init(_ profile: UserProfile) { self.profile = profile }

    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return nil }
        profile = decoded
    }

    /// An empty string on a failure the encoder should never produce. It decodes
    /// back to nil, so `@AppStorage` falls through to its default rather than
    /// storing something half-written.
    var rawValue: String {
        guard let data = try? JSONEncoder().encode(profile),
              let json = String(data: data, encoding: .utf8)
        else { return "" }
        return json
    }
}

nonisolated extension UserProfile {

    /// For code outside a view, which has no `@AppStorage` to read through —
    /// reached via `SettingsStore.userProfile`. No `.standard` default: that was
    /// how the report read the real app's profile even in previews and tests.
    static func current(in defaults: UserDefaults) -> UserProfile {
        defaults.string(forKey: storageKey)
            .flatMap(StoredProfile.init(rawValue:))?
            .profile ?? .empty
    }
}
