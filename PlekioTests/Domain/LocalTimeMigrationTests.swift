//
//  LocalTimeMigrationTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 09.11.2026.
//

import Testing
import Foundation
import SwiftData
@testable import Plekio

/// V1 kept moments; the migration rereads each as the local day or time it was in
/// the device's zone. Tbilisi here, whatever zone the tests run in.
@MainActor
@Suite("Local time migration")
struct LocalTimeMigrationTests {

    private let tbilisi: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tbilisi")!
        return calendar
    }()

    private func moment(_ day: Int, _ hour: Int) -> Date {
        tbilisi.date(from: DateComponents(year: 2030, month: 6, day: day, hour: hour))!
    }

    private func june(_ day: Int) -> LocalDay {
        LocalDay(year: 2030, month: 6, day: day)
    }

    @Test("Days and slots stored as moments become the local days and times they were")
    func momentsBecomeLocal() throws {
        let schema = PlekioSchema.current()
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = container.mainContext

        // As V1 left them: midnights and a dose time in Tbilisi, as moments.
        let course = TreatmentCourse(name: "Course", startDay: june(1), endDay: june(1))
        course.storedStartDay = moment(10, 0)
        course.storedEndDay = moment(12, 0)

        let dateRevision = CourseDateRevision(validUntilDay: june(1), startDay: june(1), endDay: june(1))
        dateRevision.storedValidUntil = moment(11, 0)
        dateRevision.storedStartDay = moment(9, 0)
        dateRevision.storedEndDay = moment(11, 0)
        course.dateRevisions.append(dateRevision)

        let medication = MedicationItem(id: UUID(), name: "Ibuprofen", form: .pill, dosage: 1, minutesOfDay: [8 * 60], frequencyDays: 1)
        medication.storedStartDay = moment(11, 0)
        let scheduleRevision = ScheduleRevision(validUntilDay: june(1), minutesOfDay: [9 * 60], frequencyDays: 1, dosage: 1)
        scheduleRevision.storedValidUntil = moment(11, 0)
        medication.scheduleRevisions.append(scheduleRevision)
        let log = DoseLog(slot: LocalSlot(day: june(1), minuteOfDay: 0), status: .taken(at: moment(10, 8), dispensed: 1))
        log.storedSlot = moment(10, 8)
        medication.logs.append(log)
        let unanchored = MedicationItem(id: UUID(), name: "Vitamin D", form: .pill, dosage: 1, minutesOfDay: [8 * 60], frequencyDays: 1)
        course.medications.append(contentsOf: [medication, unanchored])
        context.insert(course)

        try LocalTimeMigration.run(in: context, calendar: tbilisi)

        #expect(course.startDay == june(10))
        #expect(course.endDay == june(12))
        #expect(dateRevision.validUntilDay == june(11))
        #expect(dateRevision.startDay == june(9))
        #expect(dateRevision.endDay == june(11))
        #expect(medication.startDay == june(11))
        #expect(unanchored.startDay == nil)
        #expect(scheduleRevision.validUntilDay == june(11))
        #expect(log.slot == LocalSlot(day: june(10), minuteOfDay: 8 * 60))
        // A real moment, not a plan: left as it was.
        #expect(log.status == .taken(at: moment(10, 8), dispensed: 1))
    }
}
