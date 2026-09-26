//
//  UserProfileTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 19.09.2026.
//

import Testing
import Foundation
@testable import Plekio

@Suite("UserProfile")
struct UserProfileTests {

    // MARK: - Helpers

    /// UTC so age arithmetic doesn't depend on the machine's zone.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Fixed avatar id: a fresh `UUID()` per read would make `filled != filled`.
    private var filled: UserProfile {
        UserProfile(
            name: "Edward Gasparian",
            birthDate: date(1990, 6, 15),
            allergies: "penicillin",
            conditions: "hypertension",
            avatarId: UUID(uuidString: "0B1F2C3D-4E5F-6071-8293-A4B5C6D7E8F9")!
        )
    }

    // MARK: - Equality

    // Guards against == comparing encoded JSON (unstable) instead of fields.
    @Test("Equality is field by field: a profile equals itself")
    func testEqualityIsByFields() async throws {
        #expect(UserProfile.empty == UserProfile.empty)
        #expect(UserProfile.empty.isEmpty)
        #expect(filled == filled)
        #expect(filled.isEmpty == false)
    }

    // MARK: - Storage

    @Test("A profile round-trips through a string")
    func testRoundTrip() async throws {
        let restored = try #require(StoredProfile(rawValue: StoredProfile(filled).rawValue))

        #expect(restored.profile == filled)
    }

    @Test("An empty profile round-trips too")
    func testEmptyRoundTrip() async throws {
        let stored = StoredProfile(.empty)
        let restored = try #require(StoredProfile(rawValue: stored.rawValue))

        #expect(restored.profile.isEmpty)
    }

    @Test("A corrupt string fails to decode instead of producing a garbage profile")
    func testGarbageDecodesToNil() async throws {
        #expect(StoredProfile(rawValue: "")?.profile == nil)
        #expect(StoredProfile(rawValue: "{ not json")?.profile == nil)
    }

    @Test("The profile is stored field by field, not as one string")
    func testStoredAsAnObjectWithKeys() async throws {
        let json = StoredProfile(filled).rawValue

        #expect(json.hasPrefix("{"))
        #expect(json.contains("\"name\""))
        #expect(json.contains("\"birthDate\""))
    }

    @Test("A profile from the previous version is read, not discarded")
    func testMissingKeysDecodeToDefaults() async throws {
        let restored = try #require(StoredProfile(rawValue: #"{"name":"Edward"}"#)).profile

        #expect(restored.name == "Edward")
        #expect(restored.birthDate == nil)
        #expect(restored.allergies.isEmpty)
        #expect(restored.avatarId == nil)
    }

    @Test("A profile read from defaults matches the one written")
    func testCurrentReadsWhatWasStored() async throws {
        let suite = "UserProfileTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(UserProfile.current(in: defaults).isEmpty)

        defaults.set(StoredProfile(filled).rawValue, forKey: UserProfile.storageKey)

        #expect(UserProfile.current(in: defaults) == filled)
    }

    @MainActor
    @Test("SettingsStore reads the profile from its own defaults, not .standard")
    func testSettingsStoreUsesItsOwnDefaults() async throws {
        let suite = "UserProfileTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)

        settings.userProfile = filled

        // Same key and domain that @AppStorage reads.
        #expect(UserProfile.current(in: defaults) == filled)
        #expect(SettingsStore(defaults: defaults).userProfile == filled)
    }

    // MARK: - Age

    @Test("Age is computed from the birth date, not stored as a number")
    func testAgeAfterBirthdayThisYear() async throws {
        let profile = UserProfile(birthDate: date(1990, 6, 15))

        #expect(profile.age(on: date(2026, 9, 14), calendar: calendar) == 36)
    }

    @Test("Before this year's birthday the age is one less")
    func testAgeBeforeBirthdayThisYear() async throws {
        let profile = UserProfile(birthDate: date(1990, 6, 15))

        #expect(profile.age(on: date(2026, 6, 14), calendar: calendar) == 35)
        #expect(profile.age(on: date(2026, 6, 15), calendar: calendar) == 36)
    }

    @Test("No birth date, or one in the future, means no age")
    func testAgeIsNilWhenUnknown() async throws {
        #expect(UserProfile.empty.age(on: date(2026, 9, 14), calendar: calendar) == nil)

        let unborn = UserProfile(birthDate: date(2030, 1, 1))
        #expect(unborn.age(on: date(2026, 9, 14), calendar: calendar) == nil)
    }
}
