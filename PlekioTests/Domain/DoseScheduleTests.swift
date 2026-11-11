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

    // MARK: - Dose days

    private func local(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> LocalDay {
        LocalDay(year: year, month: month, day: dayOfMonth)
    }

    @Test("A course is active inclusively on both bounds")
    func testCourseWindowIsInclusive() async throws {
        let start = local(2026, 6, 10)
        let end = local(2026, 6, 12)
        let isDoseDay = { (day: LocalDay) in DoseSchedule.isDoseDay(day, start: start, end: end, frequencyDays: 1) }

        #expect(isDoseDay(start))
        #expect(isDoseDay(end))
        #expect(isDoseDay(local(2026, 6, 11)))

        #expect(!isDoseDay(local(2026, 6, 9)))
        #expect(!isDoseDay(local(2026, 6, 13)))
    }

    @Test("Every-three-days dosing falls only on its days")
    func testEveryThirdDay() async throws {
        let start = local(2026, 6, 10)
        let expected = [true, false, false, true, false, false, true]

        for (offset, isDue) in expected.enumerated() {
            #expect(
                DoseSchedule.isDoseDay(start.adding(days: offset), start: start, end: local(2026, 12, 31), frequencyDays: 3) == isDue,
                "day offset \(offset)"
            )
        }
    }

    // -3 % 3 == 0 in Swift, so a day before the start must be rejected explicitly.
    @Test("The day before the course starts isn't a dose day")
    func testDayBeforeTheCourseIsNeverADoseDay() async throws {
        let start = local(2026, 6, 10)

        #expect(!DoseSchedule.isDoseDay(local(2026, 6, 7), start: start, end: local(2026, 6, 20), frequencyDays: 3))
        #expect(!DoseSchedule.isDoseDay(local(2026, 6, 9), start: start, end: local(2026, 6, 20), frequencyDays: 1))
    }

    // Not reachable from the picker, but imported or migrated data can carry it.
    @Test("Zero frequency doesn't make every day a dose day")
    func testZeroFrequencyIsRefused() async throws {
        let start = local(2026, 6, 10)

        #expect(!DoseSchedule.isDoseDay(start, start: start, end: start, frequencyDays: 0))
        #expect(!DoseSchedule.isDoseDay(start, start: start, end: start, frequencyDays: -2))
    }

    // Counted on the days themselves: the clock change on 29 March doesn't shift every-other-day.
    @Test("Every-other-day dosing keeps its rhythm across a clock change")
    func testFrequencyAcrossDaylightSaving() async throws {
        let start = local(2026, 3, 27)

        #expect(DoseSchedule.isDoseDay(local(2026, 3, 29), start: start, end: local(2026, 4, 30), frequencyDays: 2))
        #expect(DoseSchedule.isDoseDay(local(2026, 3, 31), start: start, end: local(2026, 4, 30), frequencyDays: 2))
        #expect(!DoseSchedule.isDoseDay(local(2026, 3, 30), start: start, end: local(2026, 4, 30), frequencyDays: 2))
    }

    // MARK: - Slots of a day

    private func course(_ start: Date, _ end: Date, with medication: MedicationItem) -> TreatmentCourse {
        let course = TreatmentCourse(name: "Course", startDate: start, endDate: end)
        course.medications.append(medication)
        return course
    }

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
            for: med, in: course(start, day(2026, 6, 20), with: med),
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
        let owner = TreatmentCourse(name: "Course", startDay: LocalDay(start, in: tbilisi), endDay: LocalDay(start, in: tbilisi))
        owner.medications.append(med)

        let slots = DoseSchedule.slots(for: med, in: owner, on: start, calendar: tbilisi)

        let slot = try #require(slots.first)
        #expect(slot.hour == 8)
        #expect(tbilisi.dateComponents([.hour, .minute], from: slot.date) == DateComponents(hour: 8, minute: 0))
    }

    @Test("Outside the course and on off days there are no slots")
    func testNoSlotsOutsideTheCourseOrOffSchedule() async throws {
        let med = medication(times: [9 * 60], frequencyDays: 3)
        let owner = course(day(2026, 6, 10), day(2026, 6, 20), with: med)

        #expect(DoseSchedule.slots(for: med, in: owner, on: day(2026, 6, 21), calendar: calendar).isEmpty)

        // Inside the window, but not a dose day.
        #expect(DoseSchedule.slots(for: med, in: owner, on: day(2026, 6, 11), calendar: calendar).isEmpty)
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

        #expect(settled.contains(taken.slot))
        #expect(settled.contains(skipped.slot))
        #expect(!settled.contains(untouched.slot))
    }

    @Test("Settled slots from a day leave out the logs before it")
    func testSettledSlotsFromADay() async throws {
        let med = medication(times: [9 * 60])
        let old = DoseLog(scheduledTime: testDate(2026, 6, 10, 9, 0), status: .taken(at: Date(), dispensed: 1))
        let recent = DoseLog(scheduledTime: testDate(2026, 6, 12, 9, 0), status: .taken(at: Date(), dispensed: 1))
        med.logs.append(contentsOf: [old, recent])

        let settled = DoseSchedule.settledSlots(of: med, from: testDate(2026, 6, 12), calendar: calendar)

        #expect(settled == [recent.slot])
    }

    @Test("The log index takes only the requested day")
    func testLogsBySlotIsScopedToOneDay() async throws {
        let med = medication(times: [9 * 60])

        let today = DoseLog(scheduledTime: testDate(2026, 6, 10, 9, 0), status: .taken(at: Date(), dispensed: 1))
        let tomorrow = DoseLog(scheduledTime: testDate(2026, 6, 11, 9, 0), status: .taken(at: Date(), dispensed: 1))
        med.logs.append(contentsOf: [today, tomorrow])

        let indexed = DoseSchedule.logsBySlot(of: med, on: day(2026, 6, 10), calendar: calendar)

        #expect(indexed.count == 1)
        #expect(indexed[today.slot] === today)
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

        let fromSchedule = DoseSchedule.slots(for: med, in: course, on: start, calendar: calendar).map(\.date)

        // `now` is midnight, so no slot is filtered out as past.
        let fromNotifications = ReminderPlanner.buildScheduleMap(
            activeCourses: [course], now: start, calendar: calendar
        ).keys.sorted()

        #expect(fromSchedule == fromNotifications)
        #expect(fromSchedule.count == 2)
    }
}
