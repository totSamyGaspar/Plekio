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
            name: "Едуард Гаспарян",
            birthDate: date(1990, 6, 15),
            allergies: "пеніцилін",
            conditions: "гіпертонія",
            avatarId: UUID(uuidString: "0B1F2C3D-4E5F-6071-8293-A4B5C6D7E8F9")!
        )
    }

    // MARK: - Equality

    // Guards against == comparing encoded JSON (unstable) instead of fields.
    @Test("равенство идёт по полям: профиль равен сам себе")
    func testEqualityIsByFields() async throws {
        #expect(UserProfile.empty == UserProfile.empty)
        #expect(UserProfile.empty.isEmpty)
        #expect(filled == filled)
        #expect(filled.isEmpty == false)
    }

    // MARK: - Storage

    @Test("профиль переживает запись в строку и обратно")
    func testRoundTrip() async throws {
        let restored = try #require(StoredProfile(rawValue: StoredProfile(filled).rawValue))

        #expect(restored.profile == filled)
    }

    @Test("пустой профиль тоже переживает round-trip")
    func testEmptyRoundTrip() async throws {
        let stored = StoredProfile(.empty)
        let restored = try #require(StoredProfile(rawValue: stored.rawValue))

        #expect(restored.profile.isEmpty)
    }

    @Test("битая строка не декодируется, а не даёт мусорный профиль")
    func testGarbageDecodesToNil() async throws {
        #expect(StoredProfile(rawValue: "")?.profile == nil)
        #expect(StoredProfile(rawValue: "{ not json")?.profile == nil)
    }

    @Test("профиль пишется полями, а не одной строкой")
    func testStoredAsAnObjectWithKeys() async throws {
        let json = StoredProfile(filled).rawValue

        #expect(json.hasPrefix("{"))
        #expect(json.contains("\"name\""))
        #expect(json.contains("\"birthDate\""))
    }

    @Test("профиль из прошлой версии читается, а не отбрасывается")
    func testMissingKeysDecodeToDefaults() async throws {
        let restored = try #require(StoredProfile(rawValue: #"{"name":"Едуард"}"#)).profile

        #expect(restored.name == "Едуард")
        #expect(restored.birthDate == nil)
        #expect(restored.allergies.isEmpty)
        #expect(restored.avatarId == nil)
    }

    @Test("прочитанный из defaults профиль совпадает с записанным")
    func testCurrentReadsWhatWasStored() async throws {
        let suite = "UserProfileTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(UserProfile.current(in: defaults).isEmpty)

        defaults.set(StoredProfile(filled).rawValue, forKey: UserProfile.storageKey)

        #expect(UserProfile.current(in: defaults) == filled)
    }

    @MainActor
    @Test("SettingsStore читает профиль из своих defaults, а не из .standard")
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

    @Test("возраст считается от даты рождения, а не хранится числом")
    func testAgeAfterBirthdayThisYear() async throws {
        let profile = UserProfile(birthDate: date(1990, 6, 15))

        #expect(profile.age(on: date(2026, 9, 14), calendar: calendar) == 36)
    }

    @Test("до дня рождения в этом году возраст на год меньше")
    func testAgeBeforeBirthdayThisYear() async throws {
        let profile = UserProfile(birthDate: date(1990, 6, 15))

        #expect(profile.age(on: date(2026, 6, 14), calendar: calendar) == 35)
        #expect(profile.age(on: date(2026, 6, 15), calendar: calendar) == 36)
    }

    @Test("без даты рождения и на дате из будущего возраста нет")
    func testAgeIsNilWhenUnknown() async throws {
        #expect(UserProfile.empty.age(on: date(2026, 9, 14), calendar: calendar) == nil)

        let unborn = UserProfile(birthDate: date(2030, 1, 1))
        #expect(unborn.age(on: date(2026, 9, 14), calendar: calendar) == nil)
    }
}
