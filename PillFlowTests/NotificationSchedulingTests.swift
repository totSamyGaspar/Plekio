//
//  NotificationSchedulingTests.swift
//  PillFlowTests
//
//  Tests for NotificationService.buildScheduleMap, the pure function extracted
//  from scheduleNotifications so its scheduling rules can be tested without a
//  real UNUserNotificationCenter: grouping medications that share a trigger
//  time into one push, and skipping doses already marked as taken.
//
//  Note: the horizon is no longer a fixed number of days — it runs until the
//  notification budget is spent. Tests that are not about the horizon keep their
//  course to a single day (startDate == endDate) so exactly one day lands in the
//  schedule; the ones that are about it pass an explicit small `slotBudget`, so
//  the expected numbers stay readable instead of tracking maxScheduled.
//

import Testing
import Foundation
@testable import PillFlow

@Suite("NotificationService scheduling logic")
struct NotificationSchedulingTests {

    @Test("Multiple medications with the same time are grouped into one slot")
    func testGroupsMedicationsWithSameTime() async throws {
        let anchor = testDate(2026, 6, 15) // midnight — the "now" reference point
        let course = TreatmentCourse(name: "Утренний набор", startDate: anchor, endDate: anchor)

        let medA = MedicationItem(id: UUID(), name: "Омега-3", formSystemImage: "pills.fill", dosage: 1, timesOfDay: [testDate(2000, 1, 1, 9, 0)], frequencyDays: 1)
        let medB = MedicationItem(id: UUID(), name: "Витамин Д", formSystemImage: "pills.fill", dosage: 1, timesOfDay: [testDate(2000, 1, 1, 9, 0)], frequencyDays: 1)
        course.medications.append(contentsOf: [medA, medB])

        let map = NotificationService.buildScheduleMap(activeCourses: [course], now: anchor)

        #expect(map.count == 1)
        let entries = map.values.first
        #expect(entries?.count == 2)
        #expect(Set(entries?.map { $0.medication.name } ?? []) == ["Омега-3", "Витамин Д"])
    }

    @Test("A dose already marked as taken is excluded from the push schedule")
    func testSkipsAlreadyTakenDose() async throws {
        let anchor = testDate(2026, 6, 15)
        let doseTime = testDate(2000, 1, 1, 9, 0)
        let course = TreatmentCourse(name: "Курс", startDate: anchor, endDate: anchor)

        let med = MedicationItem(id: UUID(), name: "Ибупрофен", formSystemImage: "pills.fill", dosage: 1, timesOfDay: [doseTime], frequencyDays: 1)
        let log = DoseLog(scheduledTime: testDate(2026, 6, 15, 9, 0), isTaken: true)
        med.logs.append(log)
        course.medications.append(med)

        let map = NotificationService.buildScheduleMap(activeCourses: [course], now: anchor)

        #expect(map.isEmpty)
    }

    @Test("A dose with the same time that is NOT marked is scheduled normally")
    func testDoesNotSkipUntakenDose() async throws {
        let anchor = testDate(2026, 6, 15)
        let doseTime = testDate(2000, 1, 1, 9, 0)
        let course = TreatmentCourse(name: "Курс", startDate: anchor, endDate: anchor)

        let med = MedicationItem(id: UUID(), name: "Ибупрофен", formSystemImage: "pills.fill", dosage: 1, timesOfDay: [doseTime], frequencyDays: 1)
        course.medications.append(med)

        let map = NotificationService.buildScheduleMap(activeCourses: [course], now: anchor)

        #expect(map.count == 1)
    }

    @Test("A time in the past relative to now is excluded from the schedule")
    func testExcludesPastTimes() async throws {
        // "Now" is 22:00: the 09:00 dose is already past, the 23:00 one still
        // upcoming. One-day course so the three-day window adds nothing else.
        let now = testDate(2026, 6, 15, 22, 0)
        let dayStart = testDate(2026, 6, 15)
        let course = TreatmentCourse(name: "Курс", startDate: dayStart, endDate: dayStart)

        let med = MedicationItem(
            id: UUID(),
            name: "Магний",
            formSystemImage: "pills.fill",
            dosage: 1,
            timesOfDay: [testDate(2000, 1, 1, 9, 0), testDate(2000, 1, 1, 23, 0)],
            frequencyDays: 1
        )
        course.medications.append(med)

        let map = NotificationService.buildScheduleMap(activeCourses: [course], now: now)

        #expect(map.count == 1)
    }

    // MARK: - Horizon

    @Test("A course that fits in the budget is covered to its last day")
    func testCoversWholeCourseWhenItFits() async throws {
        // 31 days of one dose a day, well inside the default budget. The old
        // three-day window stopped here at day three and the rest of the course
        // arrived only if the user happened to open the app again.
        let anchor = testDate(2026, 6, 15)
        let course = TreatmentCourse(name: "Долгий курс", startDate: anchor, endDate: addingDays(30, to: anchor))

        let med = MedicationItem(id: UUID(), name: "Витамин C", formSystemImage: "pills.fill", dosage: 1, timesOfDay: [testDate(2000, 1, 1, 9, 0)], frequencyDays: 1)
        course.medications.append(med)

        let map = NotificationService.buildScheduleMap(activeCourses: [course], now: anchor)

        #expect(map.count == 31)
        let lastDay = map.keys.map { Calendar.current.startOfDay(for: $0) }.max()
        #expect(lastDay == Calendar.current.startOfDay(for: addingDays(30, to: anchor)))
    }

    @Test("A course longer than the budget is covered as far as the budget reaches")
    func testStopsAtTheBudget() async throws {
        let anchor = testDate(2026, 6, 15)
        let course = TreatmentCourse(name: "Годовой курс", startDate: anchor, endDate: addingDays(365, to: anchor))

        let med = MedicationItem(id: UUID(), name: "Магний", formSystemImage: "pills.fill", dosage: 1, timesOfDay: [testDate(2000, 1, 1, 9, 0)], frequencyDays: 1)
        course.medications.append(med)

        let map = NotificationService.buildScheduleMap(activeCourses: [course], now: anchor, slotBudget: 10)

        // One slot a day, so the budget converts one-to-one into days of cover.
        #expect(map.count == 10)
        #expect(Set(map.keys.map { Calendar.current.startOfDay(for: $0) }).count == 10)
    }

    @Test("A day is never covered only in part")
    func testDoesNotSplitADay() async throws {
        // Three doses a day against a budget of ten: three whole days fit, the
        // fourth would need twelve slots. Nine is the right answer — ten would mean
        // a day where the morning reminder comes and the evening one doesn't.
        let anchor = testDate(2026, 6, 15)
        let course = TreatmentCourse(name: "Курс", startDate: anchor, endDate: addingDays(30, to: anchor))

        let med = MedicationItem(
            id: UUID(),
            name: "Ибупрофен",
            formSystemImage: "pills.fill",
            dosage: 1,
            timesOfDay: [testDate(2000, 1, 1, 9, 0), testDate(2000, 1, 1, 14, 0), testDate(2000, 1, 1, 20, 0)],
            frequencyDays: 1
        )
        course.medications.append(med)

        let map = NotificationService.buildScheduleMap(activeCourses: [course], now: anchor, slotBudget: 10)

        #expect(map.count == 9)
        #expect(Set(map.keys.map { Calendar.current.startOfDay(for: $0) }).count == 3)
    }

    @Test("A first day bigger than the whole budget is still scheduled")
    func testFirstDayIsNeverDroppedForBeingTooBig() async throws {
        // Refusing to schedule anything because day one doesn't fit would be worse
        // than covering it and stopping; scheduleNotifications trims by time.
        let anchor = testDate(2026, 6, 15)
        let course = TreatmentCourse(name: "Курс", startDate: anchor, endDate: addingDays(10, to: anchor))

        let med = MedicationItem(
            id: UUID(),
            name: "Капли",
            formSystemImage: "drop.fill",
            dosage: 1,
            timesOfDay: [
                testDate(2000, 1, 1, 8, 0), testDate(2000, 1, 1, 11, 0), testDate(2000, 1, 1, 14, 0),
                testDate(2000, 1, 1, 17, 0), testDate(2000, 1, 1, 20, 0),
            ],
            frequencyDays: 1
        )
        course.medications.append(med)

        let map = NotificationService.buildScheduleMap(activeCourses: [course], now: anchor, slotBudget: 3)

        #expect(map.count == 5)
        #expect(Set(map.keys.map { Calendar.current.startOfDay(for: $0) }) == [Calendar.current.startOfDay(for: anchor)])
    }

    @Test("Frequency is counted from the course start, not from today")
    func testEveryThirdDayLandsOnTheCourseGrid() async throws {
        // The dose days are start + k*3. "Today" is two days into the course, so
        // the next dose is tomorrow — a walk that counted from today instead would
        // put it two days out and quietly shift the whole course.
        let start = testDate(2026, 6, 15)
        let now = testDate(2026, 6, 17)
        let course = TreatmentCourse(name: "Через два дня", startDate: start, endDate: addingDays(30, to: start))

        let med = MedicationItem(id: UUID(), name: "Витамин D", formSystemImage: "pills.fill", dosage: 1, timesOfDay: [testDate(2000, 1, 1, 9, 0)], frequencyDays: 3)
        course.medications.append(med)

        let map = NotificationService.buildScheduleMap(activeCourses: [course], now: now, slotBudget: 3)

        let days = map.keys.map { Calendar.current.startOfDay(for: $0) }.sorted()
        #expect(days == [
            Calendar.current.startOfDay(for: testDate(2026, 6, 18)),
            Calendar.current.startOfDay(for: testDate(2026, 6, 21)),
            Calendar.current.startOfDay(for: testDate(2026, 6, 24)),
        ])
    }
}
