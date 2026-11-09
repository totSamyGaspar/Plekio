//
//  TimeZoneTravelTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 09.11.2026.
//

import Testing
import Foundation
@testable import Plekio

/// Plekio keeps local time: a dose at 08:00 is at 08:00 wherever the person is.
/// Course days and dose slots are local days and times, so a trip doesn't move them.
@MainActor
@Suite("Time zone travel")
struct TimeZoneTravelTests {

    // MARK: - Helpers

    private func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private let tbilisi = "Asia/Tbilisi"
    private let berlin = "Europe/Berlin"

    private func day(_ month: Int, _ day: Int, in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: 2030, month: month, day: day))!
    }

    /// 10–12 June, one dose at 08:00, created in `zone` as the app does: from a picked date.
    private func course(createdIn zone: String) -> (TreatmentCourse, MedicationItem) {
        let home = calendar(zone)
        let course = TreatmentCourse(
            name: "Course",
            startDay: LocalDay(day(6, 10, in: home), in: home),
            endDay: LocalDay(day(6, 12, in: home), in: home)
        )
        let medication = MedicationItem(id: UUID(), name: "Ibuprofen", form: .pill, dosage: 1,
                                        minutesOfDay: [8 * 60], frequencyDays: 1)
        course.medications.append(medication)
        return (course, medication)
    }

    private func pills(_ course: TreatmentCourse, on month: Int, _ dayOfMonth: Int, in zone: String) -> [PillDose] {
        let local = calendar(zone)
        return DoseDay.pills(of: [course], on: day(month, dayOfMonth, in: local), calendar: local)
    }

    // MARK: - Doses

    @Test("A dose taken at home stays taken after flying west")
    func takenDoseSurvivesTravel() {
        let (course, medication) = course(createdIn: tbilisi)
        let slot = tbilisi8am(on: 10)
        medication.logs.append(DoseLog(slot: LocalSlot(slot, in: calendar(tbilisi)), status: .taken(at: slot, dispensed: 1)))

        let today = pills(course, on: 6, 10, in: berlin)
        #expect(today.count == 1)
        #expect(today.first?.isTaken == true)
    }

    @Test("At home a taken dose reads as taken")
    func takenDoseAtHome() {
        let (course, medication) = course(createdIn: tbilisi)
        let slot = tbilisi8am(on: 10)
        medication.logs.append(DoseLog(slot: LocalSlot(slot, in: calendar(tbilisi)), status: .taken(at: slot, dispensed: 1)))

        #expect(pills(course, on: 6, 10, in: tbilisi).first?.isTaken == true)
    }

    // MARK: - Course days

    @Test("A course keeps its days after flying west")
    func courseDaysSurviveTravel() {
        let (course, _) = course(createdIn: tbilisi)
        let daysWithDoses = (9...13).filter { !pills(course, on: 6, $0, in: berlin).isEmpty }

        #expect(daysWithDoses == [10, 11, 12])
    }

    @Test("A course keeps its days after flying east")
    func courseDaysSurviveEastwardTravel() {
        let (course, _) = course(createdIn: berlin)
        let daysWithDoses = (9...13).filter { !pills(course, on: 6, $0, in: tbilisi).isEmpty }

        #expect(daysWithDoses == [10, 11, 12])
    }

    // MARK: - Daylight saving

    /// 31 March 2030: Berlin skips 02:00–03:00.
    @Test("A dose time skipped by the clock change still gives one slot")
    func springForwardKeepsTheSlot() {
        let local = calendar(berlin)
        let course = TreatmentCourse(name: "Course", startDay: LocalDay(day(3, 30, in: local), in: local),
                                     endDay: LocalDay(day(4, 1, in: local), in: local))
        let medication = MedicationItem(id: UUID(), name: "Ibuprofen", form: .pill, dosage: 1,
                                        minutesOfDay: [2 * 60 + 30], frequencyDays: 1)
        course.medications.append(medication)

        let changeDay = DoseDay.pills(of: [course], on: day(3, 31, in: local), calendar: local)
        #expect(changeDay.count == 1)

        // Logged and read back on the same day: the slot must match itself.
        let slot = changeDay[0].time
        medication.logs.append(DoseLog(slot: LocalSlot(slot, in: local), status: .taken(at: slot, dispensed: 1)))
        #expect(DoseDay.pills(of: [course], on: day(3, 31, in: local), calendar: local).first?.isTaken == true)
    }

    /// 27 October 2030: Berlin goes through 02:00–03:00 twice.
    @Test("A dose time repeated by the clock change gives one slot, not two")
    func fallBackGivesOneSlot() {
        let local = calendar(berlin)
        let course = TreatmentCourse(name: "Course", startDay: LocalDay(day(10, 26, in: local), in: local),
                                     endDay: LocalDay(day(10, 28, in: local), in: local))
        course.medications.append(
            MedicationItem(id: UUID(), name: "Ibuprofen", form: .pill, dosage: 1,
                           minutesOfDay: [2 * 60 + 30], frequencyDays: 1)
        )

        #expect(DoseDay.pills(of: [course], on: day(10, 27, in: local), calendar: local).count == 1)
    }

    // MARK: - Private

    private func tbilisi8am(on dayOfMonth: Int) -> Date {
        calendar(tbilisi).date(from: DateComponents(year: 2030, month: 6, day: dayOfMonth, hour: 8))!
    }
}
