//
//  DoseScheduleTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 14.09.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("DoseSchedule rules")
struct DoseScheduleTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
        Calendar.current.startOfDay(for: testDate(year, month, dayOfMonth))
    }

    // MARK: - Course window

    @Test("A course is active inclusively on both bounds")
    func testCourseWindowIsInclusive() async throws {
        let start = day(2026, 6, 10)
        let end = day(2026, 6, 12)

        #expect(DoseSchedule.isActive(courseStartDay: start, courseEndDay: end, day: start))
        #expect(DoseSchedule.isActive(courseStartDay: start, courseEndDay: end, day: end))
        #expect(DoseSchedule.isActive(courseStartDay: start, courseEndDay: end, day: day(2026, 6, 11)))

        #expect(!DoseSchedule.isActive(courseStartDay: start, courseEndDay: end, day: day(2026, 6, 9)))
        #expect(!DoseSchedule.isActive(courseStartDay: start, courseEndDay: end, day: day(2026, 6, 13)))
    }

    // MARK: - Frequency

    @Test("A daily medication falls on every day")
    func testDailyFrequencyMatchesEveryDay() async throws {
        let start = day(2026, 6, 10)

        for offset in 0..<5 {
            let candidate = calendar.date(byAdding: .day, value: offset, to: start)!
            #expect(DoseSchedule.isDoseDay(frequencyDays: 1, courseStartDay: start, day: candidate, calendar: calendar))
        }
    }

    @Test("Every-three-days dosing falls only on its days")
    func testEveryThirdDay() async throws {
        let start = day(2026, 6, 10)
        let expected = [true, false, false, true, false, false, true]

        for (offset, isDue) in expected.enumerated() {
            let candidate = calendar.date(byAdding: .day, value: offset, to: start)!
            #expect(
                DoseSchedule.isDoseDay(frequencyDays: 3, courseStartDay: start, day: candidate, calendar: calendar) == isDue,
                "day offset \(offset)"
            )
        }
    }

    // -3 % 3 == 0 in Swift, so a negative elapsed-day count must be rejected explicitly.
    @Test("The day before the course starts isn't a dose day")
    func testDayBeforeTheCourseIsNeverADoseDay() async throws {
        let start = day(2026, 6, 10)

        #expect(!DoseSchedule.isDoseDay(frequencyDays: 3, courseStartDay: start, day: day(2026, 6, 7), calendar: calendar))
        #expect(!DoseSchedule.isDoseDay(frequencyDays: 1, courseStartDay: start, day: day(2026, 6, 9), calendar: calendar))
    }

    // Not reachable from the picker, but imported or migrated data can carry it.
    @Test("Zero frequency doesn't make every day a dose day")
    func testZeroFrequencyIsRefused() async throws {
        let start = day(2026, 6, 10)

        #expect(!DoseSchedule.isDoseDay(frequencyDays: 0, courseStartDay: start, day: start, calendar: calendar))
        #expect(!DoseSchedule.isDoseDay(frequencyDays: -2, courseStartDay: start, day: start, calendar: calendar))
    }

    // MARK: - Slot identity

    @Test("The slot key ignores seconds but not minutes")
    func testSlotKeyIdentifiesTheOccurrence() async throws {
        let nineOClock = testDate(2026, 6, 10, 9, 0)
        let nineOClockLater = nineOClock.addingTimeInterval(45)
        let ninePastNine = testDate(2026, 6, 10, 9, 1)
        let nextDay = testDate(2026, 6, 11, 9, 0)

        #expect(DoseSchedule.slotKey(nineOClock, calendar: calendar) == DoseSchedule.slotKey(nineOClockLater, calendar: calendar))
        #expect(DoseSchedule.slotKey(nineOClock, calendar: calendar) != DoseSchedule.slotKey(ninePastNine, calendar: calendar))
        #expect(DoseSchedule.slotKey(nineOClock, calendar: calendar) != DoseSchedule.slotKey(nextDay, calendar: calendar))
    }

    // MARK: - Slots of a day

    private func medication(times: [Int], frequencyDays: Int = 1) -> MedicationItem {
        MedicationItem(
            id: UUID(),
            name: "Ibuprofen",
            form: .pill,
            dosage: 1,
            minutesOfDay: times,
            frequencyDays: frequencyDays
        )
    }

    @Test("A day's slots are the dose times placed on that day")
    func testSlotsPlaceTimesOnTheDay() async throws {
        let start = day(2026, 6, 10)
        let med = medication(times: [8 * 60 + 30, 20 * 60])

        let slots = DoseSchedule.slots(
            for: med, courseStartDay: start, courseEndDay: day(2026, 6, 20),
            on: day(2026, 6, 12), calendar: calendar
        )

        #expect(slots.map(\.date) == [testDate(2026, 6, 12, 8, 30), testDate(2026, 6, 12, 20, 0)])
        #expect(slots.map(\.hour) == [8, 20])
    }

    @Test("A dose time is wall-clock: 08:00 stays 08:00 in another time zone")
    func testSlotsKeepWallClockTimeAcrossTimeZones() async throws {
        var tbilisi = Calendar(identifier: .gregorian)
        tbilisi.timeZone = try #require(TimeZone(identifier: "Asia/Tbilisi"))
        let start = tbilisi.startOfDay(for: testDate(2026, 6, 10, 12))
        let med = medication(times: [8 * 60])

        let slots = DoseSchedule.slots(for: med, courseStartDay: start, courseEndDay: start, on: start, calendar: tbilisi)

        let slot = try #require(slots.first)
        #expect(slot.hour == 8)
        #expect(tbilisi.dateComponents([.hour, .minute], from: slot.date) == DateComponents(hour: 8, minute: 0))
    }

    @Test("Outside the course and on off days there are no slots")
    func testNoSlotsOutsideTheCourseOrOffSchedule() async throws {
        let start = day(2026, 6, 10)
        let med = medication(times: [9 * 60], frequencyDays: 3)

        #expect(DoseSchedule.slots(
            for: med, courseStartDay: start, courseEndDay: day(2026, 6, 20),
            on: day(2026, 6, 21), calendar: calendar
        ).isEmpty)

        // Inside the window, but not a dose day.
        #expect(DoseSchedule.slots(
            for: med, courseStartDay: start, courseEndDay: day(2026, 6, 20),
            on: day(2026, 6, 11), calendar: calendar
        ).isEmpty)
    }

    // MARK: - Logs

    @Test("Both taken and skipped slots count as settled")
    func testSettledSlotsCoverTakenAndSkipped() async throws {
        let med = medication(times: [9 * 60])

        let taken = DoseLog(scheduledTime: testDate(2026, 6, 10, 9, 0), status: .taken(at: Date(), dispensed: 1))
        let skipped = DoseLog(scheduledTime: testDate(2026, 6, 11, 9, 0), status: .skipped(at: Date()))
        let untouched = DoseLog(scheduledTime: testDate(2026, 6, 12, 9, 0))
        med.logs.append(contentsOf: [taken, skipped, untouched])

        let settled = DoseSchedule.settledSlots(of: med, calendar: calendar)

        #expect(settled.contains(DoseSchedule.slotKey(taken.scheduledTime, calendar: calendar)))
        #expect(settled.contains(DoseSchedule.slotKey(skipped.scheduledTime, calendar: calendar)))
        #expect(!settled.contains(DoseSchedule.slotKey(untouched.scheduledTime, calendar: calendar)))
    }

    @Test("The log index takes only the requested day")
    func testLogsBySlotIsScopedToOneDay() async throws {
        let med = medication(times: [9 * 60])

        let today = DoseLog(scheduledTime: testDate(2026, 6, 10, 9, 0), status: .taken(at: Date(), dispensed: 1))
        let tomorrow = DoseLog(scheduledTime: testDate(2026, 6, 11, 9, 0), status: .taken(at: Date(), dispensed: 1))
        med.logs.append(contentsOf: [today, tomorrow])

        let indexed = DoseSchedule.logsBySlot(of: med, on: day(2026, 6, 10), calendar: calendar)

        #expect(indexed.count == 1)
        #expect(indexed[DoseSchedule.slotKey(today.scheduledTime, calendar: calendar)] === today)
    }

    // MARK: - Periods of the day

    @Test("Morning, afternoon and evening boundaries")
    func testDayPeriodBoundaries() async throws {
        #expect(DayPeriod(hour: 0) == .morning)
        #expect(DayPeriod(hour: 11) == .morning)
        #expect(DayPeriod(hour: 12) == .noon)
        #expect(DayPeriod(hour: 16) == .noon)
        #expect(DayPeriod(hour: 17) == .evening)
        #expect(DayPeriod(hour: 23) == .evening)
    }

    // MARK: - Screen and notifications agree

    // If these diverge, a dose shows on screen but never rings, or the reverse.
    @Test("The day list and the reminder schedule yield the same slots")
    func testScreenAndNotificationsSeeTheSameSlots() async throws {
        let start = day(2026, 6, 10)
        let course = TreatmentCourse(name: "Course", startDate: start, endDate: start)

        let med = medication(times: [9 * 60, 21 * 60])
        course.medications.append(med)

        let fromSchedule = DoseSchedule.slots(
            for: med,
            courseStartDay: start,
            courseEndDay: start,
            on: start,
            calendar: calendar
        ).map(\.date)

        // `now` is midnight, so no slot is filtered out as past.
        let fromNotifications = ReminderPlanner.buildScheduleMap(
            activeCourses: [course], now: start, calendar: calendar
        ).keys.sorted()

        #expect(fromSchedule == fromNotifications)
        #expect(fromSchedule.count == 2)
    }
}
