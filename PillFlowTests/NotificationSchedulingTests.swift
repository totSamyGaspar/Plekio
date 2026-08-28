//
//  NotificationSchedulingTests.swift
//  PillFlowTests
//
//  Tests for NotificationService.buildScheduleMap, the pure function extracted
//  from scheduleNotifications so its scheduling rules can be tested without a
//  real UNUserNotificationCenter: grouping medications that share a trigger
//  time into one push, and skipping doses already marked as taken.
//
//  Note: buildScheduleMap always covers a "today + next 2 days" window. Unless
//  a test exercises that window, its course is limited to a single day
//  (startDate == endDate) so exactly one day lands in the schedule.
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

    @Test("The schedule only covers today and the next 2 days")
    func testLimitsToThreeDayWindow() async throws {
        let anchor = testDate(2026, 6, 15) // midnight; a 09:00 dose that same day is still upcoming
        let course = TreatmentCourse(name: "Долгий курс", startDate: anchor, endDate: addingDays(30, to: anchor))

        let med = MedicationItem(id: UUID(), name: "Витамин C", formSystemImage: "pills.fill", dosage: 1, timesOfDay: [testDate(2000, 1, 1, 9, 0)], frequencyDays: 1)
        course.medications.append(med)

        let map = NotificationService.buildScheduleMap(activeCourses: [course], now: anchor)

        #expect(map.count == 3)
        let expectedDays: Set<Date> = [
            Calendar.current.startOfDay(for: anchor),
            Calendar.current.startOfDay(for: addingDays(1, to: anchor)),
            Calendar.current.startOfDay(for: addingDays(2, to: anchor)),
        ]
        let actualDays = Set(map.keys.map { Calendar.current.startOfDay(for: $0) })
        #expect(actualDays == expectedDays)
    }
}
