//
//  SchemaV2Fixture.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 09.11.2026.
//

import Testing
import Foundation
import SwiftData
@testable import Plekio

// MARK: - SchemaV2Fixture

/// The data in the frozen V2 store (Fixtures/SchemaV2.store), like SchemaV1Fixture.
/// Days and slots are written as local values, not moments, so the check holds in
/// any time zone: the store is written on one Mac and read on CI in UTC.
@MainActor
enum SchemaV2Fixture {

    // MARK: - Values

    static let courseId = UUID(uuidString: "11111111-0000-0000-0000-000000000011")!
    static let repeatedCourseId = UUID(uuidString: "11111111-0000-0000-0000-000000000012")!
    static let medicationId = UUID(uuidString: "22222222-0000-0000-0000-000000000011")!
    static let addedLaterId = UUID(uuidString: "22222222-0000-0000-0000-000000000012")!
    static let diaryId = UUID(uuidString: "33333333-0000-0000-0000-000000000011")!
    static let quickLogId = UUID(uuidString: "33333333-0000-0000-0000-000000000012")!
    static let photoId = UUID(uuidString: "44444444-0000-0000-0000-000000000011")!
    static let readingId = UUID(uuidString: "55555555-0000-0000-0000-000000000011")!
    static let readingWithoutPulseId = UUID(uuidString: "55555555-0000-0000-0000-000000000012")!

    /// 2026-11-01 00:00 UTC; moments (log times, check-ins, readings) are offsets from it.
    static let base = Date(timeIntervalSince1970: 1_793_491_200)

    static func moment(_ n: Double, hour: Double = 0) -> Date {
        base.addingTimeInterval(n * 86_400 + hour * 3_600)
    }

    static func day(_ n: Int) -> LocalDay {
        LocalDay(year: 2026, month: 11, day: n)
    }

    static func slot(_ n: Int, _ hour: Int, _ minute: Int = 0) -> LocalSlot {
        LocalSlot(day: day(n), minuteOfDay: hour * 60 + minute)
    }

    // MARK: - Writing

    static func populate(_ context: ModelContext) {
        let course = SchemaV2.TreatmentCourse(name: "Antibiotics", startDay: day(1), endDay: day(11))
        course.id = courseId
        course.dateRevisions.append(SchemaV2.CourseDateRevision(validUntilDay: day(3), startDay: day(2), endDay: day(8)))

        let repeated = SchemaV2.TreatmentCourse(name: "Antibiotics", startDay: day(21), endDay: day(30), repeatedFromId: courseId)
        repeated.id = repeatedCourseId

        let medication = SchemaV2.MedicationItem(
            id: medicationId,
            name: "Amoxicillin",
            form: .drops,
            dosage: 2,
            minutesOfDay: [8 * 60, 20 * 60 + 30],
            frequencyDays: 2,
            stockCount: 14,
            lowStockThreshold: 4,
            mealTiming: .afterMeal
        )
        medication.scheduleRevisions.append(SchemaV2.ScheduleRevision(validUntilDay: day(4), minutesOfDay: [9 * 60], frequencyDays: 1, dosage: 1))
        medication.logs.append(contentsOf: [
            SchemaV2.DoseLog(slot: slot(1, 8), status: .taken(at: moment(0, hour: 8.25), dispensed: 2)),
            SchemaV2.DoseLog(slot: slot(1, 20, 30), status: .taken(at: moment(0, hour: 21), dispensed: nil)),
            SchemaV2.DoseLog(slot: slot(3, 8), status: .skipped(at: moment(2, hour: 9))),
            SchemaV2.DoseLog(slot: slot(3, 20, 30), status: .pending),
        ])

        let addedLater = SchemaV2.MedicationItem(
            id: addedLaterId,
            name: "Probiotic",
            form: .capsule,
            dosage: 1,
            minutesOfDay: [12 * 60],
            frequencyDays: 1
        )
        addedLater.startDay = day(5)

        course.medications.append(contentsOf: [medication, addedLater])
        context.insert(course)
        context.insert(repeated)

        context.insert(SchemaV2.DiaryEntry(
            id: diaryId,
            checkInDate: moment(1, hour: 21),
            moodLabel: DiaryMood.good.rawValue,
            moodScore: 4,
            physicalSummary: "Lighter today",
            energyLevel: 7,
            discomfortLevel: 2,
            sleepHours: 7.5,
            sleepQuality: SleepQuality.excellent.rawValue,
            waterGlasses: 6,
            symptoms: ["Headache", "Nausea"],
            reflectionNotes: "Walked for an hour.",
            milestoneTags: ["First week"],
            photoIds: [photoId]
        ))
        context.insert(SchemaV2.DiaryEntry(
            id: quickLogId,
            checkInDate: moment(2, hour: 12),
            moodLabel: DiaryMood.neutral.rawValue,
            moodScore: 3,
            physicalSummary: "",
            energyLevel: 0,
            discomfortLevel: 0,
            sleepHours: 0,
            sleepQuality: SleepQuality.good.rawValue,
            waterGlasses: 0,
            symptoms: [],
            reflectionNotes: "",
            milestoneTags: [],
            isQuickLog: true
        ))

        context.insert(SchemaV2.BloodPressureReading(id: readingId, measuredAt: moment(1, hour: 7), systolic: 128, diastolic: 84, pulse: 72))
        context.insert(SchemaV2.BloodPressureReading(id: readingWithoutPulseId, measuredAt: moment(2, hour: 7), systolic: 119, diastolic: 77))
    }

    // MARK: - Checking

    /// Every value `populate` wrote, read back through the current models.
    static func expectMatches(_ context: ModelContext) throws {
        let courses = try context.fetch(FetchDescriptor<TreatmentCourse>(sortBy: [SortDescriptor(\.storedStartDay)]))
        #expect(courses.map(\.id) == [courseId, repeatedCourseId])

        let course = try #require(courses.first)
        #expect(course.name == "Antibiotics")
        #expect(course.startDay == day(1))
        #expect(course.endDay == day(11))
        #expect(course.repeatedFromId == nil)
        #expect(courses.last?.repeatedFromId == courseId)
        #expect(courses.last?.startDay == day(21))
        #expect(courses.last?.medications.isEmpty == true)

        let dateRevision = try #require(course.dateRevisions.first)
        #expect(course.dateRevisions.count == 1)
        #expect(dateRevision.validUntilDay == day(3))
        #expect(dateRevision.startDay == day(2))
        #expect(dateRevision.endDay == day(8))
        #expect(dateRevision.course?.id == courseId)

        let medications = course.medications.sorted { $0.name < $1.name }
        #expect(medications.map(\.id) == [medicationId, addedLaterId])

        let medication = try #require(medications.first)
        #expect(medication.name == "Amoxicillin")
        #expect(medication.form == .drops)
        #expect(medication.dosage == 2)
        #expect(medication.minutesOfDay == [8 * 60, 20 * 60 + 30])
        #expect(medication.frequencyDays == 2)
        #expect(medication.stockCount == 14)
        #expect(medication.lowStockThreshold == 4)
        #expect(medication.startDay == nil)
        #expect(medication.mealTiming == .afterMeal)
        #expect(medication.course?.id == courseId)

        let addedLater = try #require(medications.last)
        #expect(addedLater.form == .capsule)
        #expect(addedLater.startDay == day(5))
        #expect(addedLater.mealTiming == nil)

        let scheduleRevision = try #require(medication.scheduleRevisions.first)
        #expect(medication.scheduleRevisions.count == 1)
        #expect(scheduleRevision.validUntilDay == day(4))
        #expect(scheduleRevision.minutesOfDay == [9 * 60])
        #expect(scheduleRevision.frequencyDays == 1)
        #expect(scheduleRevision.dosage == 1)
        #expect(scheduleRevision.medication?.id == medicationId)

        let logs = medication.logs.sorted { $0.slot < $1.slot }
        #expect(logs.map(\.slot) == [slot(1, 8), slot(1, 20, 30), slot(3, 8), slot(3, 20, 30)])
        #expect(logs.map(\.status) == [
            .taken(at: moment(0, hour: 8.25), dispensed: 2),
            .taken(at: moment(0, hour: 21), dispensed: nil),
            .skipped(at: moment(2, hour: 9)),
            .pending,
        ])
        #expect(logs.allSatisfy { $0.medication?.id == medicationId })

        let entries = try context.fetch(FetchDescriptor<DiaryEntry>(sortBy: [SortDescriptor(\.checkInDate)]))
        #expect(entries.map(\.id) == [diaryId, quickLogId])
        let entry = try #require(entries.first)
        #expect(entry.checkInDate == moment(1, hour: 21))
        #expect(entry.moodLabel == DiaryMood.good.rawValue)
        #expect(entry.moodScore == 4)
        #expect(entry.physicalSummary == "Lighter today")
        #expect(entry.energyLevel == 7)
        #expect(entry.discomfortLevel == 2)
        #expect(entry.sleepHours == 7.5)
        #expect(entry.sleepQuality == SleepQuality.excellent.rawValue)
        #expect(entry.waterGlasses == 6)
        #expect(entry.symptoms == ["Headache", "Nausea"])
        #expect(entry.reflectionNotes == "Walked for an hour.")
        #expect(entry.milestoneTags == ["First week"])
        #expect(entry.photoIds == [photoId])
        #expect(entry.isQuickLog == false)
        #expect(entries.last?.isQuickLog == true)

        let readings = try context.fetch(FetchDescriptor<BloodPressureReading>(sortBy: [SortDescriptor(\.measuredAt)]))
        #expect(readings.map(\.id) == [readingId, readingWithoutPulseId])
        #expect(readings.first?.measuredAt == moment(1, hour: 7))
        #expect(readings.first?.systolic == 128)
        #expect(readings.first?.diastolic == 84)
        #expect(readings.first?.pulse == 72)
        #expect(readings.last?.pulse == nil)
    }
}
