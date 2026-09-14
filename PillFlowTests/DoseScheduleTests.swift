//
//  DoseScheduleTests.swift
//  PillFlowTests
//
//  The rules that decide when a dose is due used to be written twice — once in
//  DatabaseService.fetchPills for the screen, once in
//  ReminderPlanner.buildScheduleMap for the reminders — with nothing holding
//  the two in agreement. They live in DoseSchedule now, and these tests pin the
//  rules themselves down, including the cross-check that both consumers still
//  produce the same slots for the same day.
//

import Testing
import Foundation
@testable import PillFlow

@MainActor
@Suite("DoseSchedule rules")
struct DoseScheduleTests {

    private let calendar = Calendar.current

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
        Calendar.current.startOfDay(for: testDate(year, month, dayOfMonth))
    }

    // MARK: - Course window

    @Test("курс активен включительно на обеих границах")
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

    @Test("ежедневный приём приходится на каждый день")
    func testDailyFrequencyMatchesEveryDay() async throws {
        let start = day(2026, 6, 10)

        for offset in 0..<5 {
            let candidate = calendar.date(byAdding: .day, value: offset, to: start)!
            #expect(DoseSchedule.isDoseDay(frequencyDays: 1, courseStartDay: start, day: candidate, calendar: calendar))
        }
    }

    @Test("приём раз в три дня попадает только на свои дни")
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

    // Swift's remainder keeps the sign of its left operand, so -3 % 3 is 0: a day
    // three days BEFORE the course starts would read as a dose day if the elapsed
    // count were not checked for sign.
    @Test("день до начала курса не считается днём приёма")
    func testDayBeforeTheCourseIsNeverADoseDay() async throws {
        let start = day(2026, 6, 10)

        #expect(!DoseSchedule.isDoseDay(frequencyDays: 3, courseStartDay: start, day: day(2026, 6, 7), calendar: calendar))
        #expect(!DoseSchedule.isDoseDay(frequencyDays: 1, courseStartDay: start, day: day(2026, 6, 9), calendar: calendar))
    }

    // Unreachable from the picker (1/2/3/7/14/30), but imported or migrated data
    // has no such manners, and a zero divisor would make every day a dose day.
    @Test("нулевая частота не делает каждый день днём приёма")
    func testZeroFrequencyIsRefused() async throws {
        let start = day(2026, 6, 10)

        #expect(!DoseSchedule.isDoseDay(frequencyDays: 0, courseStartDay: start, day: start, calendar: calendar))
        #expect(!DoseSchedule.isDoseDay(frequencyDays: -2, courseStartDay: start, day: start, calendar: calendar))
    }

    // MARK: - Slot identity

    @Test("ключ слота игнорирует секунды, но не минуты")
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

    private func medication(times: [Date], frequencyDays: Int = 1) -> MedicationItem {
        MedicationItem(
            id: UUID(),
            name: "Ибупрофен",
            formSystemImage: "pills.fill",
            dosage: 1,
            timesOfDay: times,
            frequencyDays: frequencyDays
        )
    }

    @Test("слоты дня — это времена приёма, положенные на этот день")
    func testSlotsPlaceTimesOnTheDay() async throws {
        let start = day(2026, 6, 10)
        let med = medication(times: [testDate(2000, 1, 1, 8, 30), testDate(2000, 1, 1, 20, 0)])

        let slots = DoseSchedule.slots(
            for: med, courseStartDay: start, courseEndDay: day(2026, 6, 20),
            on: day(2026, 6, 12), calendar: calendar
        )

        #expect(slots.map(\.date) == [testDate(2026, 6, 12, 8, 30), testDate(2026, 6, 12, 20, 0)])
        #expect(slots.map(\.hour) == [8, 20])
    }

    @Test("вне курса и не в день приёма слотов нет")
    func testNoSlotsOutsideTheCourseOrOffSchedule() async throws {
        let start = day(2026, 6, 10)
        let med = medication(times: [testDate(2000, 1, 1, 9, 0)], frequencyDays: 3)

        // Outside the window.
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

    @Test("закрытыми считаются и принятые, и пропущенные слоты")
    func testSettledSlotsCoverTakenAndSkipped() async throws {
        let med = medication(times: [testDate(2000, 1, 1, 9, 0)])

        let taken = DoseLog(scheduledTime: testDate(2026, 6, 10, 9, 0), isTaken: true)
        let skipped = DoseLog(scheduledTime: testDate(2026, 6, 11, 9, 0), isTaken: false)
        skipped.skippedAt = Date()
        let untouched = DoseLog(scheduledTime: testDate(2026, 6, 12, 9, 0), isTaken: false)
        med.logs.append(contentsOf: [taken, skipped, untouched])

        let settled = DoseSchedule.settledSlots(of: med, calendar: calendar)

        #expect(settled.contains(DoseSchedule.slotKey(taken.scheduledTime, calendar: calendar)))
        #expect(settled.contains(DoseSchedule.slotKey(skipped.scheduledTime, calendar: calendar)))
        #expect(!settled.contains(DoseSchedule.slotKey(untouched.scheduledTime, calendar: calendar)))
    }

    @Test("индекс логов берёт только нужный день")
    func testLogsBySlotIsScopedToOneDay() async throws {
        let med = medication(times: [testDate(2000, 1, 1, 9, 0)])

        let today = DoseLog(scheduledTime: testDate(2026, 6, 10, 9, 0), isTaken: true)
        let tomorrow = DoseLog(scheduledTime: testDate(2026, 6, 11, 9, 0), isTaken: true)
        med.logs.append(contentsOf: [today, tomorrow])

        let indexed = DoseSchedule.logsBySlot(of: med, on: day(2026, 6, 10), calendar: calendar)

        #expect(indexed.count == 1)
        #expect(indexed[DoseSchedule.slotKey(today.scheduledTime, calendar: calendar)] === today)
    }

    // MARK: - Periods of the day

    @Test("границы утра, дня и вечера")
    func testDayPeriodBoundaries() async throws {
        #expect(DayPeriod(hour: 0) == .morning)
        #expect(DayPeriod(hour: 11) == .morning)
        #expect(DayPeriod(hour: 12) == .noon)
        #expect(DayPeriod(hour: 16) == .noon)
        #expect(DayPeriod(hour: 17) == .evening)
        #expect(DayPeriod(hour: 23) == .evening)
    }

    // MARK: - The two consumers agree

    // The whole point of the extraction. If these ever diverge again, a dose shows
    // up on the screen and never rings, or rings and is not on the screen.
    @Test("список на день и расписание уведомлений дают одни и те же слоты")
    func testScreenAndNotificationsSeeTheSameSlots() async throws {
        let start = day(2026, 6, 10)
        let course = TreatmentCourse(name: "Курс", startDate: start, endDate: start)

        let med = medication(times: [testDate(2000, 1, 1, 9, 0), testDate(2000, 1, 1, 21, 0)])
        course.medications.append(med)

        let fromSchedule = DoseSchedule.slots(
            for: med,
            courseStartDay: start,
            courseEndDay: start,
            on: start,
            calendar: calendar
        ).map(\.date)

        // `now` is midnight of that day, so every slot is still ahead and none is
        // filtered out as past.
        let fromNotifications = ReminderPlanner.buildScheduleMap(
            activeCourses: [course], now: start, calendar: calendar
        ).keys.sorted()

        #expect(fromSchedule == fromNotifications)
        #expect(fromSchedule.count == 2)
    }
}
