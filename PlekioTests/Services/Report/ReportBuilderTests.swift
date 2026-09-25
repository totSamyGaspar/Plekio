//
//  ReportBuilderTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 19.09.2026.
//

import Testing
import Foundation
import SwiftData
@testable import Plekio

@MainActor
@Suite("ReportBuilder")
struct ReportBuilderTests {

    // MARK: - Helpers

    /// After every date used below, so no dose is "upcoming" unless a test says so.
    private let afterwards = testDate(2026, 8, 1)

    private func builder(_ db: DatabaseService, now: Date) -> ReportBuilder {
        ReportBuilder(database: db, now: { now })
    }

    /// One medication, once a day at 09:00, over a June course.
    @discardableResult
    private func seedCourse(
        _ db: DatabaseService,
        start: Date = testDate(2026, 6, 1),
        end: Date = testDate(2026, 6, 10),
        frequencyDays: Int = 1
    ) -> TreatmentCourse {
        let course = TreatmentCourse(name: "Курс", startDate: start, endDate: end)
        course.medications.append(
            MedicationItem(
                id: UUID(),
                name: "Ибупрофен",
                formSystemImage: "pills.fill",
                dosage: 1,
                timesOfDay: [testDate(2000, 1, 1, 9, 0)],
                frequencyDays: frequencyDays
            )
        )
        db.context.insert(course)
        try? db.context.save()
        return course
    }

    private func selection(_ course: TreatmentCourse, from: Date, to: Date) -> ReportSelection {
        ReportSelection(from: from, to: to, courseIds: [course.id], sections: [.medications])
    }

    private func log(_ course: TreatmentCourse, at time: Date, taken: Bool, skipped: Bool = false) {
        let status: DoseStatus = taken ? .taken(at: time, dispensed: 1) : skipped ? .skipped(at: time) : .pending
        let log = DoseLog(scheduledTime: time, status: status)
        log.medication = course.medications[0]
        course.medications[0].logs.append(log)
    }

    // MARK: - Counting

    @Test("каждый день курса в периоде даёт одну назначенную дозу")
    func testEveryDoseDayIsCounted() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let course = seedCourse(db)

        let data = builder(db, now: afterwards)
            .build(selection(course, from: testDate(2026, 6, 1), to: testDate(2026, 6, 10)))

        #expect(data.courses.count == 1)
        #expect(data.courses[0].adherence.scheduled == 10)
        #expect(data.courses[0].adherence.missed == 10)
    }

    @Test("принятые, пропущенные и просроченные дозы различаются")
    func testOutcomesAreToldApart() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let course = seedCourse(db)

        log(course, at: testDate(2026, 6, 1, 9, 0), taken: true)
        log(course, at: testDate(2026, 6, 2, 9, 0), taken: false, skipped: true)
        try? db.context.save()

        let adherence = builder(db, now: afterwards)
            .build(selection(course, from: testDate(2026, 6, 1), to: testDate(2026, 6, 3)))
            .courses[0].adherence

        #expect(adherence.taken == 1)
        #expect(adherence.skipped == 1)
        #expect(adherence.missed == 1)
        #expect(adherence.scheduled == 3)
    }

    // A deliberate skip is not adherence: one taken out of three is 33%.
    @Test("доля соблюдения считается от закрытых доз")
    func testRateCountsSettledDosesOnly() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let course = seedCourse(db)

        log(course, at: testDate(2026, 6, 1, 9, 0), taken: true)
        log(course, at: testDate(2026, 6, 2, 9, 0), taken: false, skipped: true)
        try? db.context.save()

        let adherence = builder(db, now: afterwards)
            .build(selection(course, from: testDate(2026, 6, 1), to: testDate(2026, 6, 3)))
            .courses[0].adherence

        #expect(adherence.rate == 1.0 / 3.0)
    }

    @Test("будущие дозы не считаются пропущенными")
    func testFutureDosesAreUpcomingNotMissed() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let course = seedCourse(db)

        let adherence = builder(db, now: testDate(2026, 6, 3, 12, 0))
            .build(selection(course, from: testDate(2026, 6, 1), to: testDate(2026, 6, 10)))
            .courses[0].adherence

        // Three days past, seven still ahead.
        #expect(adherence.missed == 3)
        #expect(adherence.upcoming == 7)
        #expect(adherence.rate == 0)
    }

    @Test("час после срока доза ещё не просрочена")
    func testTheGracePeriodIsHonoured() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let course = seedCourse(db)

        let justInside = builder(db, now: testDate(2026, 6, 1, 9, 59))
            .build(selection(course, from: testDate(2026, 6, 1), to: testDate(2026, 6, 1)))
            .courses[0].adherence
        #expect(justInside.upcoming == 1)

        let justOutside = builder(db, now: testDate(2026, 6, 1, 10, 1))
            .build(selection(course, from: testDate(2026, 6, 1), to: testDate(2026, 6, 1)))
            .courses[0].adherence
        #expect(justOutside.missed == 1)
    }

    // MARK: - Boundaries

    @Test("период обрезается границами курса, а не наоборот")
    func testPeriodIsClippedToTheCourse() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let course = seedCourse(db, start: testDate(2026, 6, 5), end: testDate(2026, 6, 7))

        let adherence = builder(db, now: afterwards)
            .build(selection(course, from: testDate(2026, 6, 1), to: testDate(2026, 6, 30)))
            .courses[0].adherence

        #expect(adherence.scheduled == 3)
    }

    @Test("дозы вне периода не попадают в отчёт")
    func testDosesOutsideThePeriodAreLeftOut() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let course = seedCourse(db)

        let adherence = builder(db, now: afterwards)
            .build(selection(course, from: testDate(2026, 6, 3), to: testDate(2026, 6, 5)))
            .courses[0].adherence

        #expect(adherence.scheduled == 3)
    }

    @Test("приём через день даёт дозы только в свои дни")
    func testFrequencyIsRespected() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let course = seedCourse(db, frequencyDays: 3)

        let adherence = builder(db, now: afterwards)
            .build(selection(course, from: testDate(2026, 6, 1), to: testDate(2026, 6, 10)))
            .courses[0].adherence

        // 1, 4, 7 and 10 June.
        #expect(adherence.scheduled == 4)
    }

    // MARK: - Exceptions

    @Test("в список исключений попадают только незакрытые дозы")
    func testExceptionsListOnlyWhatWentWrong() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let course = seedCourse(db, end: testDate(2026, 6, 3))

        log(course, at: testDate(2026, 6, 1, 9, 0), taken: true)
        log(course, at: testDate(2026, 6, 2, 9, 0), taken: false, skipped: true)
        try? db.context.save()

        let exceptions = builder(db, now: afterwards)
            .build(selection(course, from: testDate(2026, 6, 1), to: testDate(2026, 6, 3)))
            .courses[0].medications[0].exceptions

        #expect(exceptions.count == 2)
        #expect(exceptions.map(\.kind) == [.skipped, .missed])
        #expect(exceptions.map(\.time) == [testDate(2026, 6, 2, 9, 0), testDate(2026, 6, 3, 9, 0)])
    }

    // MARK: - Sections

    @Test("невыбранный раздел не собирается вовсе")
    func testUnselectedSectionsAreNotBuilt() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let course = seedCourse(db)
        try? db.saveBloodPressureReading(
            measuredAt: testDate(2026, 6, 2, 8, 0), systolic: 120, diastolic: 80, pulse: 60
        )

        var onlyPressure = selection(course, from: testDate(2026, 6, 1), to: testDate(2026, 6, 10))
        onlyPressure.sections = [.bloodPressure]

        let data = builder(db, now: afterwards).build(onlyPressure)

        #expect(data.courses.isEmpty)
        #expect(data.pressure.count == 1)
    }

    @Test("показания давления обрезаются по периоду, включая последний день целиком")
    func testPressureIsClippedToThePeriod() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        // Before the period, on its last evening, and after it.
        for time in [testDate(2026, 5, 31, 23, 0), testDate(2026, 6, 2, 23, 50), testDate(2026, 6, 3, 0, 10)] {
            try? db.saveBloodPressureReading(measuredAt: time, systolic: 120, diastolic: 80, pulse: nil)
        }

        var onlyPressure = ReportSelection(from: testDate(2026, 6, 1), to: testDate(2026, 6, 2))
        onlyPressure.sections = [.bloodPressure]

        let data = builder(db, now: afterwards).build(onlyPressure)

        #expect(data.pressure.map(\.measuredAt) == [testDate(2026, 6, 2, 23, 50)])
    }

    @Test("фото дневника попадают в отчёт только если их попросили")
    func testDiaryPhotosFollowTheSelection() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        var draft = DiaryEntryDraft()
        draft.checkInDate = testDate(2026, 6, 2, 10, 0)
        draft.photos = [Data("photo".utf8)]
        try? db.saveDiaryEntry(draft: draft)

        var onlyDiary = ReportSelection(from: testDate(2026, 6, 1), to: testDate(2026, 6, 10))
        onlyDiary.sections = [.diary]

        let without = builder(db, now: afterwards).build(onlyDiary)
        #expect(without.diary.count == 1)
        #expect(without.diary[0].photoIds.isEmpty)

        onlyDiary.includesPhotos = true
        let with = builder(db, now: afterwards).build(onlyDiary)
        #expect(with.diary[0].photoIds.count == 1)
    }

    // MARK: - Background Read

    @Test("отчёт, собранный в фоне, совпадает с отчётом с главного потока")
    func backgroundReportMatchesMainActorBuild() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let course = seedCourse(db)
        log(course, at: testDate(2026, 6, 2, 9, 0), taken: true)
        log(course, at: testDate(2026, 6, 3, 9, 0), taken: false, skipped: true)
        try db.context.save()

        var all = selection(course, from: testDate(2026, 6, 1), to: testDate(2026, 6, 10))
        all.sections = Set(ReportSection.allCases)

        let main = builder(db, now: afterwards).build(all)
        let background = try await db.reportData(for: all, profile: .empty, now: afterwards)

        #expect(background == main)
        #expect(background.courses.first?.adherence.taken == 1)
        #expect(background.courses.first?.adherence.skipped == 1)
    }
}
