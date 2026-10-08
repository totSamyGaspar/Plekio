//
//  SchemaV1Fixture.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 08.10.2026.
//

import Testing
import Foundation
import SwiftData
@testable import Plekio

// MARK: - SchemaV1Fixture

/// The data in the frozen V1 store (Fixtures/SchemaV1.store): every model,
/// every stored field, every relationship and every DoseLog state, with fixed
/// ids and dates. The same values write the fixture and check it after a
/// migration, so the two can never disagree.
@MainActor
enum SchemaV1Fixture {

    // MARK: - Values

    static let courseId = UUID(uuidString: "11111111-0000-0000-0000-000000000001")!
    static let repeatedCourseId = UUID(uuidString: "11111111-0000-0000-0000-000000000002")!
    static let medicationId = UUID(uuidString: "22222222-0000-0000-0000-000000000001")!
    static let diaryId = UUID(uuidString: "33333333-0000-0000-0000-000000000001")!
    static let quickLogId = UUID(uuidString: "33333333-0000-0000-0000-000000000002")!
    static let photoId = UUID(uuidString: "44444444-0000-0000-0000-000000000001")!
    static let readingId = UUID(uuidString: "55555555-0000-0000-0000-000000000001")!
    static let readingWithoutPulseId = UUID(uuidString: "55555555-0000-0000-0000-000000000002")!

    /// 2026-10-01 00:00 UTC; everything else is an offset from it.
    static let base = Date(timeIntervalSince1970: 1_790_812_800)
    static func day(_ n: Double, hour: Double = 0) -> Date {
        base.addingTimeInterval(n * 86_400 + hour * 3_600)
    }

    // MARK: - Writing

    static func populate(_ context: ModelContext) {
        let course = TreatmentCourse(name: "Antibiotics", startDate: day(0), endDate: day(10))
        course.id = courseId
        course.dateRevisions.append(CourseDateRevision(validUntil: day(2), startDate: day(-1), endDate: day(7)))

        let repeated = TreatmentCourse(name: "Antibiotics", startDate: day(20), endDate: day(30), repeatedFromId: courseId)
        repeated.id = repeatedCourseId

        let medication = MedicationItem(
            id: medicationId,
            name: "Amoxicillin",
            form: .drops,
            dosage: 2,
            minutesOfDay: [8 * 60, 20 * 60 + 30],
            frequencyDays: 2,
            stockCount: 14,
            lowStockThreshold: 4,
            startDate: day(1)
        )
        medication.scheduleRevisions.append(ScheduleRevision(validUntil: day(3), minutesOfDay: [9 * 60], frequencyDays: 1, dosage: 1))
        medication.logs.append(contentsOf: [
            DoseLog(scheduledTime: day(0, hour: 8), status: .taken(at: day(0, hour: 8.25), dispensed: 2)),
            DoseLog(scheduledTime: day(0, hour: 20.5), status: .taken(at: day(0, hour: 21), dispensed: nil)),
            DoseLog(scheduledTime: day(2, hour: 8), status: .skipped(at: day(2, hour: 9))),
            DoseLog(scheduledTime: day(2, hour: 20.5), status: .pending),
        ])
        course.medications.append(medication)

        context.insert(course)
        context.insert(repeated)

        context.insert(DiaryEntry(
            id: diaryId,
            checkInDate: day(1, hour: 21),
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
        context.insert(DiaryEntry(
            id: quickLogId,
            checkInDate: day(2, hour: 12),
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

        context.insert(BloodPressureReading(id: readingId, measuredAt: day(1, hour: 7), systolic: 128, diastolic: 84, pulse: 72))
        context.insert(BloodPressureReading(id: readingWithoutPulseId, measuredAt: day(2, hour: 7), systolic: 119, diastolic: 77))
    }

    // MARK: - Checking

    /// Every value `populate` wrote, read back through the current models.
    static func expectMatches(_ context: ModelContext) throws {
        let courses = try context.fetch(FetchDescriptor<TreatmentCourse>(sortBy: [SortDescriptor(\.startDate)]))
        #expect(courses.map(\.id) == [courseId, repeatedCourseId])

        let course = try #require(courses.first)
        #expect(course.name == "Antibiotics")
        #expect(course.startDate == day(0))
        #expect(course.endDate == day(10))
        #expect(course.repeatedFromId == nil)
        #expect(courses.last?.repeatedFromId == courseId)
        #expect(courses.last?.medications.isEmpty == true)

        let dateRevision = try #require(course.dateRevisions.first)
        #expect(course.dateRevisions.count == 1)
        #expect(dateRevision.validUntil == day(2))
        #expect(dateRevision.startDate == day(-1))
        #expect(dateRevision.endDate == day(7))
        #expect(dateRevision.course?.id == courseId)

        let medication = try #require(course.medications.first)
        #expect(course.medications.count == 1)
        #expect(medication.id == medicationId)
        #expect(medication.name == "Amoxicillin")
        #expect(medication.form == .drops)
        #expect(medication.dosage == 2)
        #expect(medication.minutesOfDay == [8 * 60, 20 * 60 + 30])
        #expect(medication.frequencyDays == 2)
        #expect(medication.stockCount == 14)
        #expect(medication.lowStockThreshold == 4)
        #expect(medication.startDate == day(1))
        #expect(medication.course?.id == courseId)

        let scheduleRevision = try #require(medication.scheduleRevisions.first)
        #expect(medication.scheduleRevisions.count == 1)
        #expect(scheduleRevision.validUntil == day(3))
        #expect(scheduleRevision.minutesOfDay == [9 * 60])
        #expect(scheduleRevision.frequencyDays == 1)
        #expect(scheduleRevision.dosage == 1)
        #expect(scheduleRevision.medication?.id == medicationId)

        let statuses = medication.logs.sorted { $0.scheduledTime < $1.scheduledTime }.map(\.status)
        #expect(statuses == [
            .taken(at: day(0, hour: 8.25), dispensed: 2),
            .taken(at: day(0, hour: 21), dispensed: nil),
            .skipped(at: day(2, hour: 9)),
            .pending,
        ])
        #expect(medication.logs.allSatisfy { $0.medication?.id == medicationId })

        let entries = try context.fetch(FetchDescriptor<DiaryEntry>(sortBy: [SortDescriptor(\.checkInDate)]))
        #expect(entries.map(\.id) == [diaryId, quickLogId])
        let entry = try #require(entries.first)
        #expect(entry.checkInDate == day(1, hour: 21))
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
        #expect(readings.first?.measuredAt == day(1, hour: 7))
        #expect(readings.first?.systolic == 128)
        #expect(readings.first?.diastolic == 84)
        #expect(readings.first?.pulse == 72)
        #expect(readings.last?.pulse == nil)
    }
}
