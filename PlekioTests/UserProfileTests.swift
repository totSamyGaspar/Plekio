//
//  UserProfileTests.swift
//  PlekioTests
//
//  The profile is held by @AppStorage, which stores strings, so the whole
//  struct survives a launch only through StoredProfile. These pin down that
//  round trip, the one derived value (the age), and the reason the two are
//  separate types at all — see testEqualityIsByFields.
//

import Testing
import Foundation
@testable import Plekio

@Suite("UserProfile")
struct UserProfileTests {

    /// Fixed calendar and zone: the age arithmetic must not depend on where the
    /// test runs.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// A fixed avatar id, not a fresh `UUID()`: this is read more than once per
    /// test, and a new id on every read compares unequal to itself.
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

    // Why StoredProfile exists. When the profile was itself RawRepresentable,
    // the standard library's == took over and compared two freshly encoded JSON
    // strings instead of the fields. Two encodings of one value are not the
    // same bytes, so a profile was not equal to itself — .empty.isEmpty was
    // false, and every comparison in this file failed on values printed as
    // identical field for field.
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

    // A half-written or hand-edited defaults value must not crash the app or
    // produce a profile with garbage in it.
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

    // A profile saved by an older build has no key for anything added since.
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

    // MARK: - Age

    @Test("возраст считается от даты рождения, а не хранится числом")
    func testAgeAfterBirthdayThisYear() async throws {
        let profile = UserProfile(birthDate: date(1990, 6, 15))

        #expect(profile.age(on: date(2026, 9, 14), calendar: calendar) == 36)
    }

    // The off-by-one that a naive year subtraction gets wrong.
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
