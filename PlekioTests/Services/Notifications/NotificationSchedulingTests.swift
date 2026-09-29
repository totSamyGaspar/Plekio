//
//  NotificationSchedulingTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 22.08.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("NotificationService scheduling logic")
struct NotificationSchedulingTests {

    // MARK: - Grouping and filtering

    @Test("Multiple medications with the same time are grouped into one slot")
    func testGroupsMedicationsWithSameTime() async throws {
        let anchor = testDate(2026, 6, 15)
        let course = TreatmentCourse(name: "Morning set", startDate: anchor, endDate: anchor)

        let medA = MedicationItem(id: UUID(), name: "Omega-3", form: .pill, dosage: 1, minutesOfDay: [9 * 60], frequencyDays: 1)
        let medB = MedicationItem(id: UUID(), name: "Vitamin D", form: .pill, dosage: 1, minutesOfDay: [9 * 60], frequencyDays: 1)
        course.medications.append(contentsOf: [medA, medB])

        let map = ReminderPlanner.buildScheduleMap(activeCourses: [course], now: anchor, calendar: .current)

        #expect(map.count == 1)
        let entries = map.values.first
        #expect(entries?.count == 2)
        #expect(Set(entries?.map { $0.medication.name } ?? []) == ["Omega-3", "Vitamin D"])
    }

    @Test("A dose already marked as taken is excluded from the push schedule")
    func testSkipsAlreadyTakenDose() async throws {
        let anchor = testDate(2026, 6, 15)
        let course = TreatmentCourse(name: "Course", startDate: anchor, endDate: anchor)

        let med = MedicationItem(id: UUID(), name: "Ibuprofen", form: .pill, dosage: 1, minutesOfDay: [9 * 60], frequencyDays: 1)
        let log = DoseLog(scheduledTime: testDate(2026, 6, 15, 9, 0), status: .taken(at: testDate(2026, 6, 15, 9, 0), dispensed: 1))
        med.logs.append(log)
        course.medications.append(med)

        let map = ReminderPlanner.buildScheduleMap(activeCourses: [course], now: anchor, calendar: .current)

        #expect(map.isEmpty)
    }

    @Test("A dose with the same time that is NOT marked is scheduled normally")
    func testDoesNotSkipUntakenDose() async throws {
        let anchor = testDate(2026, 6, 15)
        let course = TreatmentCourse(name: "Course", startDate: anchor, endDate: anchor)

        let med = MedicationItem(id: UUID(), name: "Ibuprofen", form: .pill, dosage: 1, minutesOfDay: [9 * 60], frequencyDays: 1)
        course.medications.append(med)

        let map = ReminderPlanner.buildScheduleMap(activeCourses: [course], now: anchor, calendar: .current)

        #expect(map.count == 1)
    }

    @Test("A time in the past relative to now is excluded from the schedule")
    func testExcludesPastTimes() async throws {
        // One-day course, so only the 23:00 slot remains.
        let now = testDate(2026, 6, 15, 22, 0)
        let dayStart = testDate(2026, 6, 15)
        let course = TreatmentCourse(name: "Course", startDate: dayStart, endDate: dayStart)

        let med = MedicationItem(
            id: UUID(),
            name: "Magnesium",
            form: .pill,
            dosage: 1,
            minutesOfDay: [9 * 60, 23 * 60],
            frequencyDays: 1
        )
        course.medications.append(med)

        let map = ReminderPlanner.buildScheduleMap(activeCourses: [course], now: now, calendar: .current)

        #expect(map.count == 1)
    }

    // MARK: - Horizon

    @Test("A course that fits in the budget is covered to its last day")
    func testCoversWholeCourseWhenItFits() async throws {
        let anchor = testDate(2026, 6, 15)
        let course = TreatmentCourse(name: "Long course", startDate: anchor, endDate: addingDays(30, to: anchor))

        let med = MedicationItem(id: UUID(), name: "Vitamin C", form: .pill, dosage: 1, minutesOfDay: [9 * 60], frequencyDays: 1)
        course.medications.append(med)

        let map = ReminderPlanner.buildScheduleMap(activeCourses: [course], now: anchor, calendar: .current)

        #expect(map.count == 31)
        let lastDay = map.keys.map { Calendar.current.startOfDay(for: $0) }.max()
        #expect(lastDay == Calendar.current.startOfDay(for: addingDays(30, to: anchor)))
    }

    @Test("A course longer than the budget is covered as far as the budget reaches")
    func testStopsAtTheBudget() async throws {
        let anchor = testDate(2026, 6, 15)
        let course = TreatmentCourse(name: "Year-long course", startDate: anchor, endDate: addingDays(365, to: anchor))

        let med = MedicationItem(id: UUID(), name: "Magnesium", form: .pill, dosage: 1, minutesOfDay: [9 * 60], frequencyDays: 1)
        course.medications.append(med)

        let map = ReminderPlanner.buildScheduleMap(activeCourses: [course], now: anchor, calendar: .current, slotBudget: 10)

        // One slot a day, so the budget converts one-to-one into days of cover.
        #expect(map.count == 10)
        #expect(Set(map.keys.map { Calendar.current.startOfDay(for: $0) }).count == 10)
    }

    @Test("A day is never covered only in part")
    func testDoesNotSplitADay() async throws {
        // 3 doses/day, budget 10: three whole days (9 slots), never a partial fourth.
        let anchor = testDate(2026, 6, 15)
        let course = TreatmentCourse(name: "Course", startDate: anchor, endDate: addingDays(30, to: anchor))

        let med = MedicationItem(
            id: UUID(),
            name: "Ibuprofen",
            form: .pill,
            dosage: 1,
            minutesOfDay: [9 * 60, 14 * 60, 20 * 60],
            frequencyDays: 1
        )
        course.medications.append(med)

        let map = ReminderPlanner.buildScheduleMap(activeCourses: [course], now: anchor, calendar: .current, slotBudget: 10)

        #expect(map.count == 9)
        #expect(Set(map.keys.map { Calendar.current.startOfDay(for: $0) }).count == 3)
    }

    @Test("A first day bigger than the whole budget is still scheduled")
    func testFirstDayIsNeverDroppedForBeingTooBig() async throws {
        // Better to cover day one and stop; scheduleNotifications trims by time.
        let anchor = testDate(2026, 6, 15)
        let course = TreatmentCourse(name: "Course", startDate: anchor, endDate: addingDays(10, to: anchor))

        let med = MedicationItem(
            id: UUID(),
            name: "Drops",
            form: .drops,
            dosage: 1,
            minutesOfDay: [
                8 * 60, 11 * 60, 14 * 60,
                17 * 60, 20 * 60,
            ],
            frequencyDays: 1
        )
        course.medications.append(med)

        let map = ReminderPlanner.buildScheduleMap(activeCourses: [course], now: anchor, calendar: .current, slotBudget: 3)

        #expect(map.count == 5)
        #expect(Set(map.keys.map { Calendar.current.startOfDay(for: $0) }) == [Calendar.current.startOfDay(for: anchor)])
    }

    @Test("Frequency is counted from the course start, not from today")
    func testEveryThirdDayLandsOnTheCourseGrid() async throws {
        // Dose days are start + k*3, so from day 2 the next dose is tomorrow.
        let start = testDate(2026, 6, 15)
        let now = testDate(2026, 6, 17)
        let course = TreatmentCourse(name: "Every third day", startDate: start, endDate: addingDays(30, to: start))

        let med = MedicationItem(id: UUID(), name: "Vitamin D", form: .pill, dosage: 1, minutesOfDay: [9 * 60], frequencyDays: 3)
        course.medications.append(med)

        let map = ReminderPlanner.buildScheduleMap(activeCourses: [course], now: now, calendar: .current, slotBudget: 3)

        let days = map.keys.map { Calendar.current.startOfDay(for: $0) }.sorted()
        #expect(days == [
            Calendar.current.startOfDay(for: testDate(2026, 6, 18)),
            Calendar.current.startOfDay(for: testDate(2026, 6, 21)),
            Calendar.current.startOfDay(for: testDate(2026, 6, 24)),
        ])
    }

    // MARK: - Skipped doses

    @Test("A deliberately skipped dose stays out of the schedule")
    func testSkipsDeliberatelySkippedDose() async throws {
        let anchor = testDate(2026, 6, 15)
        let course = TreatmentCourse(name: "Course", startDate: anchor, endDate: anchor)

        let med = MedicationItem(id: UUID(), name: "Ibuprofen", form: .pill, dosage: 1, minutesOfDay: [9 * 60], frequencyDays: 1)
        let log = DoseLog(scheduledTime: testDate(2026, 6, 15, 9, 0), status: .skipped(at: anchor))
        med.logs.append(log)
        course.medications.append(med)

        let map = ReminderPlanner.buildScheduleMap(activeCourses: [course], now: anchor, calendar: .current)

        #expect(map.isEmpty)
    }

    @Test("Skipping one dose doesn't take the course's other days with it")
    func testSkippingOneOccurrenceLeavesTheRestOfTheCourse() async throws {
        let anchor = testDate(2026, 6, 15)
        let course = TreatmentCourse(
            name: "Course",
            startDate: anchor,
            endDate: testDate(2026, 6, 17)
        )

        let med = MedicationItem(id: UUID(), name: "Ibuprofen", form: .pill, dosage: 1, minutesOfDay: [9 * 60], frequencyDays: 1)
        let skipped = DoseLog(scheduledTime: testDate(2026, 6, 15, 9, 0), status: .skipped(at: anchor))
        med.logs.append(skipped)
        course.medications.append(med)

        let map = ReminderPlanner.buildScheduleMap(activeCourses: [course], now: anchor, calendar: .current)

        // The 15th is gone; the 16th and the 17th are not.
        let scheduledDays = Set(map.keys.map { Calendar.current.component(.day, from: $0) })
        #expect(scheduledDays == [16, 17])
    }
}
