//
//  DailyReminderTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 04.09.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("DailyReminder Tests", .serialized)
struct DailyReminderTests {

    // MARK: - Storage keys

    @Test("Keys match those the previous version wrote")
    func testKeysStayCompatible() async throws {
        // Migration-sensitive: changing a key silently drops existing users' reminders.
        #expect(DailyReminder.diary.enabledKey == "diaryReminderEnabled")
        #expect(DailyReminder.diary.legacyMinuteOfDayKey == "diaryReminderMinuteOfDay")
        #expect(DailyReminder.diary.timesKey == "diaryReminderMinutesOfDay")

        #expect(DailyReminder.bloodPressure.enabledKey == "bloodPressureReminderEnabled")
        #expect(DailyReminder.bloodPressure.timesKey == "bloodPressureReminderMinutesOfDay")
    }

    @Test("The diary's first slot keeps the identifier already in users' queues")
    func testFirstRequestIdentifierIsUnchanged() async throws {
        // Must match the queued request so re-arming replaces it instead of duplicating.
        #expect(DailyReminder.diary.requestIdentifier(at: 0) == "DIARY_REMINDER")
        #expect(DailyReminder.bloodPressure.requestIdentifier(at: 0) == "BLOOD_PRESSURE_REMINDER")
        #expect(DailyReminder.bloodPressure.requestIdentifier(at: 2) == "BLOOD_PRESSURE_REMINDER_2")
    }

    @Test("Cancellation lists every slot, not just the used ones")
    func testAllRequestIdentifiersCoverEverySlot() async throws {
        // Removed times must be cancelled too, or they keep firing.
        #expect(DailyReminder.diary.allRequestIdentifiers == ["DIARY_REMINDER"])
        #expect(DailyReminder.bloodPressure.allRequestIdentifiers == [
            "BLOOD_PRESSURE_REMINDER",
            "BLOOD_PRESSURE_REMINDER_1",
            "BLOOD_PRESSURE_REMINDER_2",
        ])
    }

    @Test("How many times a day each reminder can fire")
    func testMaxTimes() async throws {
        // Each time permanently uses one of iOS's 64 pending notification slots.
        #expect(DailyReminder.diary.maxTimes == 1)
        #expect(DailyReminder.bloodPressure.maxTimes == 3)
    }

    // MARK: - Times as text

    @Test("The order of times is kept; they aren't sorted on read")
    func testParsingKeepsTheOrderTheUserEntered() async throws {
        // Sorting on read would reshuffle rows while the user drags them.
        #expect(DailyReminder.minutes(fromRaw: "1260,540", limit: 3) == [1260, 540])
    }

    @Test("Parsing the times string: garbage, out-of-day values and the limit")
    func testParsingIsDefensive() async throws {
        #expect(DailyReminder.minutes(fromRaw: "540,abc,,780", limit: 3) == [540, 780])
        #expect(DailyReminder.minutes(fromRaw: "-30,2000", limit: 3) == [0, 24 * 60 - 1])
        #expect(DailyReminder.minutes(fromRaw: "1,2,3,4", limit: 3) == [1, 2, 3])
        #expect(DailyReminder.minutes(fromRaw: "", limit: 3).isEmpty)
    }

    @Test("Writing and reading times round-trips")
    func testRawRoundTrip() async throws {
        let times = [9 * 60, 13 * 60 + 30, 21 * 60]
        let raw = DailyReminder.raw(from: times)

        #expect(raw == "540,810,1260")
        #expect(DailyReminder.minutes(fromRaw: raw, limit: 3) == times)
    }

    @Test("Minutes past midnight split into hours and minutes, clamped at the ends")
    func testHourAndMinute() async throws {
        let morning = MinuteOfDay.hourAndMinute(9 * 60 + 5)
        #expect(morning.hour == 9)
        #expect(morning.minute == 5)

        let underflow = MinuteOfDay.hourAndMinute(-1)
        #expect(underflow.hour == 0)
        #expect(underflow.minute == 0)

        let overflow = MinuteOfDay.hourAndMinute(24 * 60)
        #expect(overflow.hour == 23)
        #expect(overflow.minute == 59)
    }

    // MARK: - Resolving the stored times

    @Test("Without stored values the default is used")
    func testFallsBackToDefaults() async throws {
        withIsolatedSettings { settings, _ in
            #expect(settings.minutesOfDay(for: .bloodPressure) == [9 * 60])
            #expect(settings.isEnabled(.bloodPressure) == false)
        }
    }

    @Test("A time from the previous version is picked up, not reset to the default")
    func testReadsTheLegacySingleTimeKey() async throws {
        withIsolatedSettings { settings, defaults in
            defaults.set(7 * 60 + 45, forKey: DailyReminder.diary.legacyMinuteOfDayKey)

            #expect(settings.minutesOfDay(for: .diary) == [7 * 60 + 45])
        }
    }

    @Test("The new key takes precedence over the old one")
    func testNewKeyWinsOverLegacy() async throws {
        withIsolatedSettings { settings, defaults in
            defaults.set(7 * 60, forKey: DailyReminder.diary.legacyMinuteOfDayKey)
            defaults.set("1320", forKey: DailyReminder.diary.timesKey)

            #expect(settings.minutesOfDay(for: .diary) == [22 * 60])
        }
    }

    @Test("There can't be more stored times than the reminder allows")
    func testStoredTimesRespectTheCap() async throws {
        withIsolatedSettings { settings, defaults in
            // Stored lists longer than the cap (e.g. from an older build) are truncated.
            defaults.set("540,780,1020,1260", forKey: DailyReminder.diary.timesKey)

            #expect(settings.minutesOfDay(for: .diary) == [540])
        }
    }

    @Test("An enabled reminder is read from the same domain @AppStorage writes to")
    func testEnabledFlagIsReadFromTheStoresDomain() async throws {
        withIsolatedSettings { settings, defaults in
            defaults.set(true, forKey: DailyReminder.diary.enabledKey)

            #expect(settings.isEnabled(.diary))
            #expect(settings.isEnabled(.bloodPressure) == false)
        }
    }

    // MARK: - Helpers

    /// Runs `body` with a SettingsStore over a throwaway defaults suite.
    private func withIsolatedSettings(_ body: (SettingsStore, UserDefaults) -> Void) {
        let suite = "PlekioTests.DailyReminder.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("could not create a UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        body(SettingsStore(defaults: defaults), defaults)
    }
}
