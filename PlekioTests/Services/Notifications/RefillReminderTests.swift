//
//  RefillReminderTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 26.09.2026.
//

import Testing
import Foundation
@testable import Plekio

@Suite("RefillReminder")
struct RefillReminderTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2030, month: 6, day: day, hour: hour))!
    }

    private func course(stocks: [(String, Int)]) -> TreatmentCourse {
        let course = TreatmentCourse(name: "Course", startDate: date(1, 0), endDate: date(30, 0))
        for (name, stock) in stocks {
            course.medications.append(
                MedicationItem(id: UUID(), name: name, formSystemImage: "pills.fill", dosage: 1,
                               timesOfDay: [date(1, 9)], frequencyDays: 1,
                               stockCount: stock, lowStockThreshold: 10)
            )
        }
        return course
    }

    // MARK: - Plan

    @Test("Nothing low, no reminder")
    func nothingLowMeansNoPlan() {
        let plan = RefillReminder.plan(activeCourses: [course(stocks: [("A", 30)])], minuteOfDay: RefillReminder.defaultMinuteOfDay, now: date(10, 8), calendar: calendar)
        #expect(plan == nil)
    }

    @Test("The reminder lists every low medication, including one exactly at the threshold")
    func listsEveryLowMedication() {
        let courses = [course(stocks: [("B", 10), ("C", 30), ("A", 2)])]
        let plan = RefillReminder.plan(activeCourses: courses, minuteOfDay: RefillReminder.defaultMinuteOfDay, now: date(10, 8), calendar: calendar)
        #expect(plan?.medicationNames == ["A", "B"])
    }

    @Test("Fires today at 10:00 if that time hasn't passed")
    func firesTodayBeforeTheHour() {
        let plan = RefillReminder.plan(activeCourses: [course(stocks: [("A", 1)])], minuteOfDay: RefillReminder.defaultMinuteOfDay, now: date(10, 8), calendar: calendar)
        #expect(plan?.fireDate == date(10, 10))
    }

    @Test("After 10:00 it moves to tomorrow")
    func firesTomorrowAfterTheHour() {
        let plan = RefillReminder.plan(activeCourses: [course(stocks: [("A", 1)])], minuteOfDay: RefillReminder.defaultMinuteOfDay, now: date(10, 12), calendar: calendar)
        #expect(plan?.fireDate == date(11, 10))
    }

    @Test("Fires at the time the user chose")
    func firesAtTheChosenTime() {
        let plan = RefillReminder.plan(
            activeCourses: [course(stocks: [("A", 1)])],
            minuteOfDay: 19 * 60 + 30,
            now: date(10, 12),
            calendar: calendar
        )
        #expect(plan?.fireDate == calendar.date(from: DateComponents(year: 2030, month: 6, day: 10, hour: 19, minute: 30)))
    }
}
