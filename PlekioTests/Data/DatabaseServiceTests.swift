//
//  DatabaseServiceTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 22.08.2026.
//

import Testing
import Combine
import Foundation
import SwiftData
@testable import Plekio

@MainActor
@Suite("DatabaseService Tests")
struct DatabaseServiceTests {

    // MARK: - fetchPills: splitting by time of day

    @Test("fetchPills splits doses into periods of day (morning/noon/evening)")
    func testFetchPillsSplitsByPeriod() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        let course = TreatmentCourse(name: "Course", startDate: testDate(2026, 6, 1), endDate: testDate(2026, 6, 30))
        let med = MedicationItem(
            id: UUID(),
            name: "Ibuprofen",
            form: .pill,
            dosage: 2,
            minutesOfDay: [
                8 * 60,   // morning
                14 * 60,  // noon
                20 * 60,  // evening
            ],
            frequencyDays: 1,
            stockCount: 30,
            lowStockThreshold: 10
        )
        course.medications.append(med)
        db.context.insert(course)
        try? db.context.save()

        let pills = db.fetchPills(for: testDate(2026, 6, 5))

        #expect(pills.count == 3)
        #expect(pills.map(\.period) == [.morning, .noon, .evening])
        #expect(pills.allSatisfy { $0.name == "Ibuprofen" && $0.dosage == 2 })
    }

    // MARK: - fetchPills: dosing interval (frequencyDays)

    @Test("fetchPills respects frequencyDays — a dose lands only on its own days")
    func testFetchPillsRespectsFrequencyInterval() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        let courseStart = testDate(2026, 6, 1)
        let course = TreatmentCourse(name: "Every-3-days course", startDate: courseStart, endDate: testDate(2026, 6, 30))
        let med = MedicationItem(
            id: UUID(),
            name: "Vitamin B12",
            form: .pill,
            dosage: 1,
            minutesOfDay: [9 * 60],
            frequencyDays: 3,
            stockCount: 10,
            lowStockThreshold: 3
        )
        course.medications.append(med)
        db.context.insert(course)
        try? db.context.save()

        // Interval counts from the course start: days 0 and 3 match, 1 and 2 don't.
        #expect(db.fetchPills(for: courseStart).count == 1)
        #expect(db.fetchPills(for: addingDays(1, to: courseStart)).isEmpty)
        #expect(db.fetchPills(for: addingDays(2, to: courseStart)).isEmpty)
        #expect(db.fetchPills(for: addingDays(3, to: courseStart)).count == 1)
    }

    // MARK: - togglePill: stock tracking and DoseLog

    @Test("togglePill creates a DoseLog, deducts stock, and a second call reverts it")
    func testTogglePillTracksStockAndLog() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        let course = TreatmentCourse(name: "Course", startDate: testDate(2026, 6, 1), endDate: testDate(2026, 6, 30))
        let med = MedicationItem(
            id: UUID(),
            name: "Aspirin",
            form: .pill,
            dosage: 2,
            minutesOfDay: [9 * 60],
            frequencyDays: 1,
            stockCount: 30,
            lowStockThreshold: 10
        )
        course.medications.append(med)
        db.context.insert(course)
        try? db.context.save()

        let scheduledTime = testDate(2026, 6, 10, 9, 0)

        try db.togglePill(medicationId: med.id, scheduledTime: scheduledTime)
        #expect(med.logs.count == 1)
        #expect(med.logs.first?.status.isTaken == true)
        #expect(med.stockCount == 28)

        try db.togglePill(medicationId: med.id, scheduledTime: scheduledTime)
        #expect(med.logs.count == 1) // DoseLog is reused, not duplicated
        #expect(med.logs.first?.status.isTaken == false)
        #expect(med.stockCount == 30)
    }

    @Test("Moving a dose time carries today's logs along")
    func testChangingScheduleMovesExistingLogs() async throws {
        // "Today" is the day of the log: today's logs follow the dose to its new time.
        let db = DatabaseService(inMemoryForTesting: true, photos: FakePhotoStore(), errors: SpyErrorReporter(),
                                 time: FixedTime(testDate(2026, 6, 10, 12, 0)))
        let med = makeCourseWithMed(db)
        let day = testDate(2026, 6, 10)

        try db.togglePill(medicationId: med.id, scheduledTime: testDate(2026, 6, 10, 9, 0))
        #expect(db.fetchPills(for: day).first?.isTaken == true)

        // Existing logs must follow the dose to its new time.
        var draft = MedicationDraft(from: MedicationSnapshot(med))
        draft.minutesOfDay = [11 * 60]
        try db.updateMedication(med, with: draft)

        let pills = db.fetchPills(for: day)
        #expect(pills.count == 1)
        #expect(pills.first?.isTaken == true)
        #expect(Calendar.current.component(.hour, from: try #require(pills.first).time) == 11)
    }

    @Test("A schedule change doesn't rewrite past days")
    func testChangingScheduleKeepsThePast() async throws {
        let db = DatabaseService(inMemoryForTesting: true, photos: FakePhotoStore(), errors: SpyErrorReporter(),
                                 time: FixedTime(testDate(2026, 6, 10, 12, 0)))
        let med = makeCourseWithMed(db)
        let yesterday = testDate(2026, 6, 9)
        try db.togglePill(medicationId: med.id, scheduledTime: testDate(2026, 6, 9, 9, 0))

        var draft = MedicationDraft(from: MedicationSnapshot(med))
        draft.minutesOfDay = [11 * 60, 21 * 60]
        try db.updateMedication(med, with: draft)

        // Yesterday: still one dose at 9:00, still taken.
        let past = db.fetchPills(for: yesterday)
        #expect(past.count == 1)
        #expect(past.first?.isTaken == true)
        #expect(Calendar.current.component(.hour, from: try #require(past.first).time) == 9)

        // From today on: the new schedule.
        let today = db.fetchPills(for: testDate(2026, 6, 10))
        #expect(today.map { Calendar.current.component(.hour, from: $0.time) } == [11, 21])
        #expect(med.scheduleRevisions.count == 1)
    }

    @Test("Editing the schedule twice in a day adds no revisions and keeps the original past")
    func testEditingTwiceTodayKeepsOneRevision() async throws {
        let db = DatabaseService(inMemoryForTesting: true, photos: FakePhotoStore(), errors: SpyErrorReporter(),
                                 time: FixedTime(testDate(2026, 6, 10, 12, 0)))
        let med = makeCourseWithMed(db)

        var draft = MedicationDraft(from: MedicationSnapshot(med))
        draft.minutesOfDay = [11 * 60]
        try db.updateMedication(med, with: draft)
        draft.minutesOfDay = [13 * 60]
        try db.updateMedication(med, with: draft)

        #expect(med.scheduleRevisions.count == 1)
        let past = db.fetchPills(for: testDate(2026, 6, 9))
        #expect(past.map { Calendar.current.component(.hour, from: $0.time) } == [9])
    }

    @Test("Changing the frequency doesn't change past statistics")
    func testChangingFrequencyKeepsPastDoseDays() async throws {
        let db = DatabaseService(inMemoryForTesting: true, photos: FakePhotoStore(), errors: SpyErrorReporter(),
                                 time: FixedTime(testDate(2026, 6, 10, 12, 0)))
        let med = makeCourseWithMed(db)

        var draft = MedicationDraft(from: MedicationSnapshot(med))
        draft.frequencyDays = 2
        try db.updateMedication(med, with: draft)

        // Every past day keeps its dose (course starts June 1, daily before the change).
        let pastDays = (1...9).map { testDate(2026, 6, $0) }
        #expect(pastDays.allSatisfy { db.fetchPills(for: $0).count == 1 })
    }

    @Test("Changing the dosage doesn't change past days' dosage")
    func testChangingDosageKeepsThePast() async throws {
        let db = DatabaseService(inMemoryForTesting: true, photos: FakePhotoStore(), errors: SpyErrorReporter(),
                                 time: FixedTime(testDate(2026, 6, 10, 12, 0)))
        let med = makeCourseWithMed(db, dosage: 2)

        var draft = MedicationDraft(from: MedicationSnapshot(med))
        draft.dosage = 1
        try db.updateMedication(med, with: draft)

        #expect(db.fetchPills(for: testDate(2026, 6, 9)).first?.dosage == 2)
        #expect(db.fetchPills(for: testDate(2026, 6, 10)).first?.dosage == 1)
    }

    @Test("A medication added to a running course has no missed doses before it was added")
    func testMedicationAddedMidCourseStartsToday() async throws {
        let db = DatabaseService(inMemoryForTesting: true, photos: FakePhotoStore(), errors: SpyErrorReporter(),
                                 time: FixedTime(testDate(2026, 6, 10, 12, 0)))
        let course = makeCourseWithMed(db).course
        let owner = try #require(course)

        var draft = MedicationDraft()
        draft.name = "Magnesium"
        draft.minutesOfDay = [20 * 60]
        draft.frequencyDays = 1
        try db.addMedication(draft: draft, to: owner)

        let names: (Date) -> [String] = { day in db.fetchPills(for: day).map(\.name) }
        #expect(!names(testDate(2026, 6, 9)).contains("Magnesium"))
        #expect(names(testDate(2026, 6, 10)).contains("Magnesium"))
    }

    // MARK: - refillStock

    @Test("Moving the course start keeps past doses, logs and the old frequency anchor")
    func courseStartEditKeepsHistory() throws {
        let db = DatabaseService(inMemoryForTesting: true, photos: FakePhotoStore(), errors: SpyErrorReporter(),
                                 time: FixedTime(testDate(2026, 6, 10, 12)))
        let med = makeCourseWithMed(db)
        let course = try #require(med.course)
        med.frequencyDays = 2
        try db.context.save()
        try db.markDosesTaken(medicationIds: [med.id], scheduledTime: testDate(2026, 6, 9, 9))
        let days = (1...9).map { testDate(2026, 6, $0) }
        let before = db.fetchPills(onDays: days)

        try db.updateCourseDetails(course: course, name: course.name,
                                   startDate: testDate(2026, 6, 12), endDate: course.endDate)

        #expect(db.fetchPills(onDays: days) == before)
        #expect(db.fetchPills(for: testDate(2026, 6, 10)).isEmpty)
        #expect(db.fetchPills(for: testDate(2026, 6, 12)).count == 1)
        #expect(db.fetchPills(for: testDate(2026, 6, 13)).isEmpty)
    }

    @Test("Shortening or extending a course cannot erase or invent doses before today")
    func courseEndEditKeepsHistory() throws {
        let clock = FixedTime(testDate(2026, 6, 10, 12))
        let db = DatabaseService(inMemoryForTesting: true, photos: FakePhotoStore(), errors: SpyErrorReporter(), time: clock)
        let course = try #require(makeCourseWithMed(db).course)
        let days = (1...9).map { testDate(2026, 6, $0) }
        let before = db.fetchPills(onDays: days)
        try db.updateCourseDetails(course: course, name: course.name,
                                   startDate: course.startDate, endDate: testDate(2026, 6, 5))
        #expect(db.fetchPills(onDays: days) == before)
        #expect(db.fetchPills(for: testDate(2026, 6, 10)).isEmpty)

        clock.now = testDate(2026, 6, 12, 12)
        try db.updateCourseDetails(course: course, name: course.name,
                                   startDate: course.startDate, endDate: testDate(2026, 6, 30))
        #expect(db.fetchPills(onDays: days) == before)
        #expect(db.fetchPills(for: testDate(2026, 6, 11)).isEmpty)
        #expect(db.fetchPills(for: testDate(2026, 6, 12)).count == 1)
        #expect(course.dateRevisions.count == 2)
    }

    @Test("Repeated date edits today keep the first history; name-only edits create no revision")
    func repeatedCourseDateEditsKeepOriginalHistory() throws {
        let db = DatabaseService(inMemoryForTesting: true, photos: FakePhotoStore(), errors: SpyErrorReporter(),
                                 time: FixedTime(testDate(2026, 6, 10, 12)))
        let course = try #require(makeCourseWithMed(db).course)
        try db.updateCourseDetails(course: course, name: "Renamed", startDate: course.startDate, endDate: course.endDate)
        #expect(course.dateRevisions.isEmpty)
        for start in [12, 15] {
            try db.updateCourseDetails(course: course, name: course.name,
                                       startDate: testDate(2026, 6, start), endDate: course.endDate)
        }
        #expect(course.dateRevisions.count == 1)
        #expect(db.fetchPills(for: testDate(2026, 6, 2)).count == 1)
        #expect(db.fetchPills(for: testDate(2026, 6, 12)).isEmpty)
    }

    @Test("Moving a future course backwards does not invent missed doses")
    func movingFutureCourseBackKeepsEmptyPast() throws {
        let db = DatabaseService(inMemoryForTesting: true, photos: FakePhotoStore(), errors: SpyErrorReporter(),
                                 time: FixedTime(testDate(2026, 6, 10, 12)))
        let course = try #require(makeCourseWithMed(db).course)
        course.startDate = testDate(2026, 6, 20)
        try db.context.save()
        try db.updateCourseDetails(course: course, name: course.name,
                                   startDate: testDate(2026, 6, 1), endDate: course.endDate)
        #expect(db.fetchPills(for: testDate(2026, 6, 9)).isEmpty)
        #expect(db.fetchPills(for: testDate(2026, 6, 10)).count == 1)
    }

    @Test("Medication edits after postponing a course still preserve its past schedule")
    func medicationEditAfterCoursePostponementKeepsPast() throws {
        let db = DatabaseService(inMemoryForTesting: true, photos: FakePhotoStore(), errors: SpyErrorReporter(),
                                 time: FixedTime(testDate(2026, 6, 10, 12)))
        let med = makeCourseWithMed(db)
        let course = try #require(med.course)
        try db.updateCourseDetails(course: course, name: course.name,
                                   startDate: testDate(2026, 6, 20), endDate: course.endDate)
        var draft = MedicationDraft(from: MedicationSnapshot(med))
        draft.minutesOfDay = [11 * 60]
        draft.dosage = 1
        try db.updateMedication(med, with: draft)
        let yesterday = try #require(db.fetchPills(for: testDate(2026, 6, 9)).first)
        #expect(yesterday.time == testDate(2026, 6, 9, 9))
        #expect(yesterday.dosage == 2)
    }

    @Test("A medication added after postponing a course does not appear in its old history")
    func newMedicationAfterCoursePostponementHasNoPast() throws {
        let db = DatabaseService(inMemoryForTesting: true, photos: FakePhotoStore(), errors: SpyErrorReporter(),
                                 time: FixedTime(testDate(2026, 6, 10, 12)))
        let course = try #require(makeCourseWithMed(db).course)
        try db.updateCourseDetails(course: course, name: course.name,
                                   startDate: testDate(2026, 6, 20), endDate: course.endDate)
        var draft = MedicationDraft()
        draft.name = "New medication"
        draft.minutesOfDay = [11 * 60]
        try db.addMedication(draft: draft, to: course)
        #expect(!db.fetchPills(for: testDate(2026, 6, 9)).contains { $0.medicationId == draft.id })
        #expect(db.fetchPills(for: testDate(2026, 6, 20)).contains { $0.medicationId == draft.id })
    }

    @Test("refillStock increases stockCount by the given amount")
    func testRefillStock() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        let med = MedicationItem(
            id: UUID(),
            name: "Magnesium",
            form: .pill,
            dosage: 1,
            minutesOfDay: [9 * 60],
            frequencyDays: 1,
            stockCount: 5,
            lowStockThreshold: 10
        )

        try db.refillStock(for: med, amount: 10)

        #expect(med.stockCount == 15)
    }

    // MARK: - updateMedication: photo on disk (not a blob)

    @Test("updateMedication saves or deletes the photo on disk depending on the draft")
    func testUpdateMedicationPersistsPhotoToDisk() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        let course = TreatmentCourse(name: "Course", startDate: testDate(2026, 6, 1), endDate: testDate(2026, 6, 30))
        let med = MedicationItem(
            id: UUID(),
            name: "Omega-3",
            form: .pill,
            dosage: 1,
            minutesOfDay: [9 * 60],
            frequencyDays: 1,
            stockCount: 10,
            lowStockThreshold: 3
        )
        course.medications.append(med)
        db.context.insert(course)
        try? db.context.save()

        var draftWithPhoto = MedicationDraft()
        draftWithPhoto.name = "Omega-3"
        let fakeJPEGBytes = Data([0xFF, 0xD8, 0xFF, 0x00, 0x01, 0x02])
        draftWithPhoto.medicationImageData = fakeJPEGBytes
        draftWithPhoto.photoModified = true

        try db.updateMedication(med, with: draftWithPhoto)
        #expect(db.photos.loadDataFromDisk(for: med.id) == fakeJPEGBytes)

        // No photoModified: keep the file even though the draft has no bytes (preload may be pending).
        var renameOnly = MedicationDraft()
        renameOnly.name = "Omega-3 Forte"
        try db.updateMedication(med, with: renameOnly)
        #expect(db.photos.loadDataFromDisk(for: med.id) == fakeJPEGBytes)

        // photoModified with no bytes deletes the file.
        var draftWithoutPhoto = MedicationDraft()
        draftWithoutPhoto.name = "Omega-3"
        draftWithoutPhoto.photoModified = true
        try db.updateMedication(med, with: draftWithoutPhoto)
        #expect(db.photos.loadDataFromDisk(for: med.id) == nil)
    }

    // MARK: - deleteMedication / deleteCourse: cleaning up photo files

    @Test("deleteMedication removes the medication's photo file from disk")
    func testDeleteMedicationRemovesPhotoFile() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        let med = MedicationItem(
            id: UUID(),
            name: "Calcium",
            form: .pill,
            dosage: 1,
            minutesOfDay: [9 * 60],
            frequencyDays: 1
        )
        db.photos.saveToDisk(Data([0x01]), for: med.id)
        #expect(db.photos.loadDataFromDisk(for: med.id) != nil)

        try db.deleteMedication(med)

        #expect(db.photos.loadDataFromDisk(for: med.id) == nil)
    }

    @Test("deleteCourse removes the photo files of all its medications")
    func testDeleteCourseRemovesAllMedicationPhotoFiles() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        let course = TreatmentCourse(name: "Course", startDate: testDate(2026, 6, 1), endDate: testDate(2026, 6, 30))
        let medA = MedicationItem(id: UUID(), name: "A", form: .pill, dosage: 1, minutesOfDay: [9 * 60], frequencyDays: 1)
        let medB = MedicationItem(id: UUID(), name: "B", form: .pill, dosage: 1, minutesOfDay: [9 * 60], frequencyDays: 1)
        course.medications.append(contentsOf: [medA, medB])
        db.context.insert(course)
        try? db.context.save()

        db.photos.saveToDisk(Data([0x01]), for: medA.id)
        db.photos.saveToDisk(Data([0x02]), for: medB.id)

        try db.deleteCourse(course)

        #expect(db.photos.loadDataFromDisk(for: medA.id) == nil)
        #expect(db.photos.loadDataFromDisk(for: medB.id) == nil)
    }

    // MARK: - Diary

    @Test("saveDiaryEntry persists the draft's fields and writes its photos to disk")
    func testSaveDiaryEntryPersistsFieldsAndPhotos() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        var draft = DiaryEntryDraft()
        draft.mood = .good
        draft.physicalSummary = "Clear-headed and relaxed."
        draft.energyLevel = 4
        draft.discomfortLevel = 0
        draft.sleepHours = 7.5
        draft.sleepQuality = .good
        draft.waterGlasses = 6
        draft.symptoms = ["Mild Nausea"]
        draft.reflectionNotes = "Felt good today."
        draft.milestoneTags = ["Day 14 Milestone"]
        draft.photos = [Data([0xFF, 0xD8, 0xFF])]

        try db.saveDiaryEntry(draft: draft)

        let entries = db.fetchAllDiaryEntries()
        #expect(entries.count == 1)

        let saved = try #require(entries.first)
        #expect(saved.moodLabel == "Good")
        #expect(saved.moodScore == 4)
        #expect(saved.physicalSummary == "Clear-headed and relaxed.")
        #expect(saved.sleepQuality == "G")
        #expect(saved.symptoms == ["Mild Nausea"])
        #expect(saved.milestoneTags == ["Day 14 Milestone"])
        #expect(saved.photoIds.count == 1)

        for photoId in saved.photoIds {
            #expect(db.photos.loadDataFromDisk(for: photoId) == Data([0xFF, 0xD8, 0xFF]))
        }
    }

    @Test("updateDiaryEntry replaces photo files on disk when photosModified is set")
    func testUpdateDiaryEntryOverwritesFieldsAndPhotos() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        var original = DiaryEntryDraft()
        original.mood = .good
        original.photos = [Data([0x01])]
        original.photosModified = true
        try db.saveDiaryEntry(draft: original)

        let saved = try #require(db.fetchAllDiaryEntries().first)
        let oldPhotoId = try #require(saved.photoIds.first)
        #expect(db.photos.loadDataFromDisk(for: oldPhotoId) != nil)

        var updatedDraft = DiaryEntryDraft()
        updatedDraft.mood = .inPain
        updatedDraft.physicalSummary = "Worse today."
        updatedDraft.photos = [Data([0x02])]
        updatedDraft.photosModified = true

        try db.updateDiaryEntry(saved, with: updatedDraft)

        #expect(saved.moodLabel == "In Pain")
        #expect(saved.moodScore == 1)
        #expect(saved.physicalSummary == "Worse today.")
        #expect(saved.photoIds.count == 1)

        let newPhotoId = try #require(saved.photoIds.first)
        #expect(newPhotoId != oldPhotoId)
        #expect(db.photos.loadDataFromDisk(for: newPhotoId) == Data([0x02]))
        #expect(db.photos.loadDataFromDisk(for: oldPhotoId) == nil)

    }

    @Test("When a photo is added, untouched ones keep their ids and files")
    func updateKeepsUnchangedPhotoIds() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        var original = DiaryEntryDraft()
        original.photos = [Data([0x01])]
        try db.saveDiaryEntry(draft: original)
        let saved = try #require(db.fetchAllDiaryEntries().first)
        let keptId = try #require(saved.photoIds.first)

        var edited = DiaryEntryDraft()
        edited.photos = [Data([0x01]), Data([0x02])]
        edited.photosModified = true
        try db.updateDiaryEntry(saved, with: edited)

        #expect(saved.photoIds.count == 2)
        #expect(saved.photoIds.first == keptId)
        #expect(db.photos.loadDataFromDisk(for: keptId) == Data([0x01]))
    }

    @Test("If a new photo fails to write, the entry is unchanged and old photos stay")
    func failedPhotoWriteKeepsTheOldEntry() async throws {
        let store = FakePhotoStore()
        let db = DatabaseService(inMemoryForTesting: true, photos: store, errors: SpyErrorReporter())
        var original = DiaryEntryDraft()
        original.physicalSummary = "Before"
        original.photos = [Data([0x01])]
        try db.saveDiaryEntry(draft: original)
        let saved = try #require(db.fetchAllDiaryEntries().first)
        let oldIds = saved.photoIds

        store.refusesWrites = true
        var edited = DiaryEntryDraft()
        edited.physicalSummary = "After"
        edited.photos = [Data([0x02])]
        edited.photosModified = true

        #expect(throws: DatabaseError.self) { try db.updateDiaryEntry(saved, with: edited) }

        #expect(saved.photoIds == oldIds)
        #expect(saved.physicalSummary == "Before")
        #expect(store.deleted.isEmpty)
        #expect(store.saved[oldIds[0]] == Data([0x01]))
    }

    @Test("A new entry with an unwritten photo isn't saved at all")
    func failedPhotoWriteRefusesANewEntry() async throws {
        let db = DatabaseService(inMemoryForTesting: true, photos: FakePhotoStore(refusesWrites: true), errors: SpyErrorReporter())
        var draft = DiaryEntryDraft()
        draft.photos = [Data([0x01])]

        #expect(throws: DatabaseError.self) { try db.saveDiaryEntry(draft: draft) }
        #expect(db.fetchAllDiaryEntries().isEmpty)
    }

    @Test("updateDiaryEntry leaves photo files untouched when photosModified is false")
    func testUpdateDiaryEntryLeavesPhotosUntouchedWhenNotModified() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        var original = DiaryEntryDraft()
        original.mood = .good
        original.photos = [Data([0x01])]
        original.photosModified = true
        try db.saveDiaryEntry(draft: original)

        let saved = try #require(db.fetchAllDiaryEntries().first)
        let originalPhotoId = try #require(saved.photoIds.first)

        // Edit screen preloads existing photo bytes; photosModified stays false.
        var updatedDraft = DiaryEntryDraft()
        updatedDraft.mood = .inPain
        updatedDraft.photos = [Data([0x01])]

        try db.updateDiaryEntry(saved, with: updatedDraft)

        #expect(saved.moodLabel == "In Pain")
        // Same file, not rewritten under a new UUID.
        #expect(saved.photoIds == [originalPhotoId])
        #expect(db.photos.loadDataFromDisk(for: originalPhotoId) == Data([0x01]))

    }

    @Test("deleteDiaryEntry removes the entry's photo files from disk")
    func testDeleteDiaryEntryRemovesPhotoFiles() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        var draft = DiaryEntryDraft()
        draft.photos = [Data([0x01]), Data([0x02])]
        try db.saveDiaryEntry(draft: draft)

        let saved = try #require(db.fetchAllDiaryEntries().first)
        let photoIds = saved.photoIds
        #expect(photoIds.count == 2)
        #expect(photoIds.allSatisfy { db.photos.loadDataFromDisk(for: $0) != nil })

        try db.deleteDiaryEntry(saved)

        #expect(db.fetchAllDiaryEntries().isEmpty)
        #expect(photoIds.allSatisfy { db.photos.loadDataFromDisk(for: $0) == nil })
    }

    // MARK: - Helpers

    /// One course with a single medication, dosed at 9:00 every day.
    private func makeCourseWithMed(
        _ db: DatabaseService,
        stockCount: Int = 30,
        dosage: Int = 2
    ) -> MedicationItem {
        let course = TreatmentCourse(name: "Course", startDate: testDate(2026, 6, 1), endDate: testDate(2026, 6, 30))
        let med = MedicationItem(
            id: UUID(),
            name: "Aspirin",
            form: .pill,
            dosage: dosage,
            minutesOfDay: [9 * 60],
            frequencyDays: 1,
            stockCount: stockCount,
            lowStockThreshold: 10
        )
        course.medications.append(med)
        db.context.insert(course)
        try? db.context.save()
        return med
    }

    // MARK: - Cache invalidation

    @Test("togglePill clears the whole cache, not just the slot's day")
    func testTogglePillInvalidatesCacheForAllDays() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = makeCourseWithMed(db)

        // Cached doses carry a copy of stockCount.
        let otherDay = testDate(2026, 6, 10)
        #expect(db.fetchPills(for: otherDay).first?.stockCount == 30)

        // Stock is shared across days, so a write on another day must invalidate this one.
        try db.togglePill(medicationId: med.id, scheduledTime: testDate(2026, 6, 11, 9, 0))

        #expect(db.fetchPills(for: otherDay).first?.stockCount == 28)
    }

    @Test("Any write clears the cache, not just logging a dose")
    func testAnyWriteInvalidatesTheCache() async throws {
        // Every write goes through commit(), which resets the cache — refill included.
        let db = DatabaseService(inMemoryForTesting: true)
        let med = makeCourseWithMed(db)

        #expect(db.fetchPills(for: testDate(2026, 6, 10)).first?.stockCount == 30)

        try db.refillStock(for: med, amount: 10)

        #expect(db.fetchPills(for: testDate(2026, 6, 10)).first?.stockCount == 40)
    }

    // MARK: - Change payload

    @Test("A subscriber wakes only for the areas it cares about")
    func testChangeFeedMatching() {
        let feed = DatabaseChangeFeed()
        var heard: [String] = []
        let subscriptions = [
            feed.publisher(for: [.courses, .doses]).sink { heard.append("dashboard") },
            feed.publisher(for: [.diary]).sink { heard.append("diary") },
            feed.publisher(for: [.courses]).sink { heard.append("photo") }
        ]
        defer { subscriptions.forEach { $0.cancel() } }

        feed.send([.diary])
        #expect(heard == ["diary"])

        // Photo views must not reload on dose writes.
        heard.removeAll()
        feed.send([.doses])
        #expect(heard == ["dashboard"])

        // Partial overlap is enough.
        heard.removeAll()
        feed.send([.courses, .diary])
        #expect(Set(heard) == ["dashboard", "diary", "photo"])
    }

    @Test("A write is announced on its own store's feed, not every store in the process")
    func testCommitAnnouncesOnItsOwnFeedOnly() throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let other = DatabaseService(inMemoryForTesting: true)
        var ownHeard = 0
        var otherHeard = 0
        let own = db.changes.publisher(for: [.courses]).sink { ownHeard += 1 }
        let foreign = other.changes.publisher(for: [.courses]).sink { otherHeard += 1 }
        defer { own.cancel(); foreign.cancel() }

        // The helper saves directly; only the refill goes through commit.
        let med = makeCourseWithMed(db)
        try db.refillStock(for: med, amount: 5)

        #expect(ownHeard == 1)
        #expect(otherHeard == 0)
    }

    // MARK: - togglePill: stock floor and back-dated logging

    @Test("Stock never goes negative")
    func testStockNeverGoesNegative() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = makeCourseWithMed(db, stockCount: 1, dosage: 2)

        try db.togglePill(medicationId: med.id, scheduledTime: testDate(2026, 6, 10, 9, 0))

        #expect(med.stockCount == 0)
        #expect(med.logs.first?.status.isTaken == true)
    }

    @Test("A past day's dose is logged with actualTakeTime after the scheduled time")
    func testLateLoggingRecordsActualTime() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = makeCourseWithMed(db)

        let scheduled = testDate(2026, 6, 10, 9, 0)
        try db.togglePill(medicationId: med.id, scheduledTime: scheduled)

        let log = try #require(med.logs.first)
        #expect(log.status.isTaken)
        #expect(log.scheduledTime == scheduled)
        // takenAt is the real log time, so lateness needs no separate field.
        let actualTakeTime = try #require(log.status.takenAt)
        #expect(actualTakeTime > scheduled)

        #expect(db.fetchPills(for: testDate(2026, 6, 10)).first?.isTaken == true)
    }

    // MARK: - Stock accounting at the bottom of the bottle

    // Stock is clamped at zero; DoseLog records what was actually dispensed and undo returns exactly that.

    /// One medication with the given stock and dosage in an in-memory store.
    private func medication(stock: Int, dosage: Int, in db: DatabaseService) -> MedicationItem {
        let course = TreatmentCourse(name: "Course", startDate: testDate(2026, 6, 1), endDate: testDate(2026, 6, 30))
        let med = MedicationItem(
            id: UUID(),
            name: "Aspirin",
            form: .pill,
            dosage: dosage,
            minutesOfDay: [9 * 60],
            frequencyDays: 1,
            stockCount: stock,
            lowStockThreshold: 10
        )
        course.medications.append(med)
        db.context.insert(course)
        try? db.context.save()
        return med
    }

    @Test("Unlogging with empty stock doesn't create pills")
    func testUndoAtZeroStockInventsNothing() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = medication(stock: 0, dosage: 2, in: db)
        let slot = testDate(2026, 6, 10, 9, 0)

        try db.togglePill(medicationId: med.id, scheduledTime: slot)
        #expect(med.stockCount == 0)
        #expect(med.logs.first?.status.dispensed == 0)

        try db.togglePill(medicationId: med.id, scheduledTime: slot)
        #expect(med.stockCount == 0)
        #expect(med.logs.first?.status.dispensed == nil)
    }

    @Test("Partial stock: exactly what was deducted is restored")
    func testUndoReturnsExactlyWhatWasDispensed() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = medication(stock: 1, dosage: 2, in: db)
        let slot = testDate(2026, 6, 10, 9, 0)

        try db.togglePill(medicationId: med.id, scheduledTime: slot)
        #expect(med.stockCount == 0)
        #expect(med.logs.first?.status.dispensed == 1)

        try db.togglePill(medicationId: med.id, scheduledTime: slot)
        #expect(med.stockCount == 1)
    }

    @Test("The usual case is unchanged: the full dose is deducted and restored")
    func testFullDoseRoundTripIsUnchanged() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = medication(stock: 10, dosage: 2, in: db)
        let slot = testDate(2026, 6, 10, 9, 0)

        try db.togglePill(medicationId: med.id, scheduledTime: slot)
        #expect(med.stockCount == 8)
        #expect(med.logs.first?.status.dispensed == 2)

        try db.togglePill(medicationId: med.id, scheduledTime: slot)
        #expect(med.stockCount == 10)
    }

    @Test("Changing the dosage after a log doesn't change the amount restored")
    func testUndoIgnoresADosageChangedAfterTheFact() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = medication(stock: 10, dosage: 2, in: db)
        let slot = testDate(2026, 6, 10, 9, 0)

        try db.togglePill(medicationId: med.id, scheduledTime: slot)
        #expect(med.stockCount == 8)

        med.dosage = 5
        try? db.context.save()

        // Returns the 2 dispensed, not the new dosage of 5.
        try db.togglePill(medicationId: med.id, scheduledTime: slot)
        #expect(med.stockCount == 10)
    }

    @Test("Skipping a dose leaves stock alone")
    func testSkipLeavesStockAlone() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = medication(stock: 10, dosage: 2, in: db)
        let slot = testDate(2026, 6, 10, 9, 0)

        try db.skipDoses(medicationIds: [med.id], scheduledTime: slot)

        // dispensed stays nil: 0 would mean "taken from an empty bottle".
        #expect(med.stockCount == 10)
        #expect(med.logs.first?.status.isSkipped == true)
        #expect(med.logs.first?.status.isTaken == false)
        #expect(med.logs.first?.status.dispensed == nil)
    }

    @Test("Changing your mind after a skip deducts the dose as usual")
    func testTakingAfterASkipDeductsStock() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = medication(stock: 10, dosage: 2, in: db)
        let slot = testDate(2026, 6, 10, 9, 0)

        try db.skipDoses(medicationIds: [med.id], scheduledTime: slot)
        try db.togglePill(medicationId: med.id, scheduledTime: slot)

        #expect(med.logs.count == 1)   // the skip's log is reused
        #expect(med.logs.first?.status.isTaken == true)
        #expect(med.logs.first?.status.isSkipped == false)
        #expect(med.stockCount == 8)
    }

    // MARK: - Bulk logging

    @Test("markDosesTaken writes the whole slot and leaves an already taken dose alone")
    func testMarkDosesTakenIsIdempotentPerDose() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        let course = TreatmentCourse(name: "Course", startDate: testDate(2026, 6, 1), endDate: testDate(2026, 6, 30))
        let times = [9 * 60]
        let first = MedicationItem(id: UUID(), name: "Aspirin", form: .pill, dosage: 2, minutesOfDay: times, frequencyDays: 1, stockCount: 30, lowStockThreshold: 10)
        let second = MedicationItem(id: UUID(), name: "Magnesium", form: .capsule, dosage: 1, minutesOfDay: times, frequencyDays: 1, stockCount: 10, lowStockThreshold: 5)
        course.medications.append(contentsOf: [first, second])
        db.context.insert(course)
        try? db.context.save()

        let slot = testDate(2026, 6, 10, 9, 0)

        try db.togglePill(medicationId: first.id, scheduledTime: slot)
        #expect(first.stockCount == 28)

        try db.markDosesTaken(medicationIds: [first.id, second.id], scheduledTime: slot)

        // Already-taken dose: not toggled off, not deducted twice.
        #expect(first.logs.count == 1)
        #expect(first.logs.first?.status.isTaken == true)
        #expect(first.stockCount == 28)

        #expect(second.logs.count == 1)
        #expect(second.logs.first?.status.isTaken == true)
        #expect(second.stockCount == 9)
    }

    @Test("markDosesTaken on a settled slot writes nothing")
    func testMarkDosesTakenOnAClosedSlotIsANoOp() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = medication(stock: 10, dosage: 2, in: db)
        let slot = testDate(2026, 6, 10, 9, 0)

        try db.markDosesTaken(medicationIds: [med.id], scheduledTime: slot)
        #expect(med.stockCount == 8)

        try db.markDosesTaken(medicationIds: [med.id], scheduledTime: slot)

        #expect(med.logs.count == 1)
        #expect(med.stockCount == 8)
    }

    @Test("markDosesTaken over a skip clears the skip and deducts stock")
    func testMarkDosesTakenClearsASkip() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = medication(stock: 10, dosage: 2, in: db)
        let slot = testDate(2026, 6, 10, 9, 0)

        try db.skipDoses(medicationIds: [med.id], scheduledTime: slot)
        try db.markDosesTaken(medicationIds: [med.id], scheduledTime: slot)

        #expect(med.logs.count == 1)
        #expect(med.logs.first?.status.isTaken == true)
        #expect(med.logs.first?.status.isSkipped == false)
        #expect(med.stockCount == 8)
    }

    @Test("unmarkDosesTaken restores deducted stock and doesn't log untaken doses")
    func testUnmarkDosesTakenOnlyReversesWhatWasLogged() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        let course = TreatmentCourse(name: "Course", startDate: testDate(2026, 6, 1), endDate: testDate(2026, 6, 30))
        let times = [9 * 60]
        let logged = MedicationItem(id: UUID(), name: "Aspirin", form: .pill, dosage: 2, minutesOfDay: times, frequencyDays: 1, stockCount: 30, lowStockThreshold: 10)
        let untouched = MedicationItem(id: UUID(), name: "Magnesium", form: .capsule, dosage: 1, minutesOfDay: times, frequencyDays: 1, stockCount: 10, lowStockThreshold: 5)
        course.medications.append(contentsOf: [logged, untouched])
        db.context.insert(course)
        try? db.context.save()

        let slot = testDate(2026, 6, 10, 9, 0)
        try db.markDosesTaken(medicationIds: [logged.id], scheduledTime: slot)
        #expect(logged.stockCount == 28)

        try db.unmarkDosesTaken(medicationIds: [logged.id, untouched.id], scheduledTime: slot)

        #expect(logged.logs.first?.status.isTaken == false)
        #expect(logged.logs.first?.status.dispensed == nil)
        #expect(logged.stockCount == 30)

        #expect(untouched.logs.isEmpty)
        #expect(untouched.stockCount == 10)
    }

    // MARK: - Background History

    @Test("Dose history read in the background matches a main-thread read")
    func backgroundHistoryMatchesMainActorRead() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = makeCourseWithMed(db)
        let slot = testDate(2026, 6, 10, 9, 0)
        try db.togglePill(medicationId: med.id, scheduledTime: slot)

        let days = (8...12).map { testDate(2026, 6, $0) }
        let background = await db.pillHistory(onDays: days)
        let main = db.fetchPills(onDays: days)

        #expect(background == main)
        #expect(background[testDate(2026, 6, 10)]?.first?.isTaken == true)
        #expect(background[testDate(2026, 6, 11)]?.first?.isTaken == false)
    }
}
