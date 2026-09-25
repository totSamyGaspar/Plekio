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

        let course = TreatmentCourse(name: "Курс", startDate: testDate(2026, 6, 1), endDate: testDate(2026, 6, 30))
        let med = MedicationItem(
            id: UUID(),
            name: "Ибупрофен",
            formSystemImage: "pills.fill",
            dosage: 2,
            timesOfDay: [
                testDate(2000, 1, 1, 8, 0),   // morning
                testDate(2000, 1, 1, 14, 0),  // noon
                testDate(2000, 1, 1, 20, 0),  // evening
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
        #expect(pills.allSatisfy { $0.name == "Ибупрофен" && $0.dosage == 2 })
    }

    // MARK: - fetchPills: dosing interval (frequencyDays)

    @Test("fetchPills respects frequencyDays — a dose lands only on its own days")
    func testFetchPillsRespectsFrequencyInterval() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        let courseStart = testDate(2026, 6, 1)
        let course = TreatmentCourse(name: "Курс раз в 3 дня", startDate: courseStart, endDate: testDate(2026, 6, 30))
        let med = MedicationItem(
            id: UUID(),
            name: "Витамин B12",
            formSystemImage: "pills.fill",
            dosage: 1,
            timesOfDay: [testDate(2000, 1, 1, 9, 0)],
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

        let course = TreatmentCourse(name: "Курс", startDate: testDate(2026, 6, 1), endDate: testDate(2026, 6, 30))
        let med = MedicationItem(
            id: UUID(),
            name: "Аспирин",
            formSystemImage: "pills.fill",
            dosage: 2,
            timesOfDay: [testDate(2000, 1, 1, 9, 0)],
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

    @Test("сдвиг времени приёма переносит сегодняшние отметки")
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
        draft.timesOfDay = [testDate(2000, 1, 1, 11, 0)]
        try db.updateMedication(med, with: draft)

        let pills = db.fetchPills(for: day)
        #expect(pills.count == 1)
        #expect(pills.first?.isTaken == true)
        #expect(Calendar.current.component(.hour, from: try #require(pills.first).time) == 11)
    }

    @Test("изменение расписания не переписывает прошлые дни")
    func testChangingScheduleKeepsThePast() async throws {
        let db = DatabaseService(inMemoryForTesting: true, photos: FakePhotoStore(), errors: SpyErrorReporter(),
                                 time: FixedTime(testDate(2026, 6, 10, 12, 0)))
        let med = makeCourseWithMed(db)
        let yesterday = testDate(2026, 6, 9)
        try db.togglePill(medicationId: med.id, scheduledTime: testDate(2026, 6, 9, 9, 0))

        var draft = MedicationDraft(from: MedicationSnapshot(med))
        draft.timesOfDay = [testDate(2000, 1, 1, 11, 0), testDate(2000, 1, 1, 21, 0)]
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

    @Test("правка расписания дважды за день не плодит ревизий и держит исходное прошлое")
    func testEditingTwiceTodayKeepsOneRevision() async throws {
        let db = DatabaseService(inMemoryForTesting: true, photos: FakePhotoStore(), errors: SpyErrorReporter(),
                                 time: FixedTime(testDate(2026, 6, 10, 12, 0)))
        let med = makeCourseWithMed(db)

        var draft = MedicationDraft(from: MedicationSnapshot(med))
        draft.timesOfDay = [testDate(2000, 1, 1, 11, 0)]
        try db.updateMedication(med, with: draft)
        draft.timesOfDay = [testDate(2000, 1, 1, 13, 0)]
        try db.updateMedication(med, with: draft)

        #expect(med.scheduleRevisions.count == 1)
        let past = db.fetchPills(for: testDate(2026, 6, 9))
        #expect(past.map { Calendar.current.component(.hour, from: $0.time) } == [9])
    }

    @Test("смена частоты не меняет прошлую статистику")
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

    @Test("смена дозировки не меняет дозировку прошлых дней")
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

    @Test("лекарство, добавленное в идущий курс, не даёт пропусков за дни до добавления")
    func testMedicationAddedMidCourseStartsToday() async throws {
        let db = DatabaseService(inMemoryForTesting: true, photos: FakePhotoStore(), errors: SpyErrorReporter(),
                                 time: FixedTime(testDate(2026, 6, 10, 12, 0)))
        let course = makeCourseWithMed(db).course
        let owner = try #require(course)

        var draft = MedicationDraft()
        draft.name = "Магний"
        draft.timesOfDay = [testDate(2000, 1, 1, 20, 0)]
        draft.frequencyDays = 1
        try db.addMedication(draft: draft, to: owner)

        let names: (Date) -> [String] = { day in db.fetchPills(for: day).map(\.name) }
        #expect(!names(testDate(2026, 6, 9)).contains("Магний"))
        #expect(names(testDate(2026, 6, 10)).contains("Магний"))
    }

    // MARK: - refillStock

    @Test("refillStock increases stockCount by the given amount")
    func testRefillStock() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        let med = MedicationItem(
            id: UUID(),
            name: "Магний",
            formSystemImage: "pills.fill",
            dosage: 1,
            timesOfDay: [testDate(2000, 1, 1, 9, 0)],
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

        let course = TreatmentCourse(name: "Курс", startDate: testDate(2026, 6, 1), endDate: testDate(2026, 6, 30))
        let med = MedicationItem(
            id: UUID(),
            name: "Омега-3",
            formSystemImage: "pills.fill",
            dosage: 1,
            timesOfDay: [testDate(2000, 1, 1, 9, 0)],
            frequencyDays: 1,
            stockCount: 10,
            lowStockThreshold: 3
        )
        course.medications.append(med)
        db.context.insert(course)
        try? db.context.save()

        var draftWithPhoto = MedicationDraft()
        draftWithPhoto.name = "Омега-3"
        let fakeJPEGBytes = Data([0xFF, 0xD8, 0xFF, 0x00, 0x01, 0x02])
        draftWithPhoto.medicationImageData = fakeJPEGBytes
        draftWithPhoto.photoModified = true

        try db.updateMedication(med, with: draftWithPhoto)
        #expect(db.photos.loadDataFromDisk(for: med.id) == fakeJPEGBytes)

        // No photoModified: keep the file even though the draft has no bytes (preload may be pending).
        var renameOnly = MedicationDraft()
        renameOnly.name = "Омега-3 форте"
        try db.updateMedication(med, with: renameOnly)
        #expect(db.photos.loadDataFromDisk(for: med.id) == fakeJPEGBytes)

        // photoModified with no bytes deletes the file.
        var draftWithoutPhoto = MedicationDraft()
        draftWithoutPhoto.name = "Омега-3"
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
            name: "Кальций",
            formSystemImage: "pills.fill",
            dosage: 1,
            timesOfDay: [testDate(2000, 1, 1, 9, 0)],
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

        let course = TreatmentCourse(name: "Курс", startDate: testDate(2026, 6, 1), endDate: testDate(2026, 6, 30))
        let medA = MedicationItem(id: UUID(), name: "A", formSystemImage: "pills.fill", dosage: 1, timesOfDay: [testDate(2000, 1, 1, 9, 0)], frequencyDays: 1)
        let medB = MedicationItem(id: UUID(), name: "B", formSystemImage: "pills.fill", dosage: 1, timesOfDay: [testDate(2000, 1, 1, 9, 0)], frequencyDays: 1)
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

    @Test("при добавлении фото нетронутые сохраняют свои id и файлы")
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

    @Test("если новое фото не записалось, запись не меняется и старые фото на месте")
    func failedPhotoWriteKeepsTheOldEntry() async throws {
        let store = FakePhotoStore()
        let db = DatabaseService(inMemoryForTesting: true, photos: store, errors: SpyErrorReporter())
        var original = DiaryEntryDraft()
        original.physicalSummary = "До"
        original.photos = [Data([0x01])]
        try db.saveDiaryEntry(draft: original)
        let saved = try #require(db.fetchAllDiaryEntries().first)
        let oldIds = saved.photoIds

        store.refusesWrites = true
        var edited = DiaryEntryDraft()
        edited.physicalSummary = "После"
        edited.photos = [Data([0x02])]
        edited.photosModified = true

        #expect(throws: DatabaseError.self) { try db.updateDiaryEntry(saved, with: edited) }

        #expect(saved.photoIds == oldIds)
        #expect(saved.physicalSummary == "До")
        #expect(store.deleted.isEmpty)
        #expect(store.saved[oldIds[0]] == Data([0x01]))
    }

    @Test("новая запись с незаписанным фото не сохраняется вовсе")
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
        let course = TreatmentCourse(name: "Курс", startDate: testDate(2026, 6, 1), endDate: testDate(2026, 6, 30))
        let med = MedicationItem(
            id: UUID(),
            name: "Аспирин",
            formSystemImage: "pills.fill",
            dosage: dosage,
            timesOfDay: [testDate(2000, 1, 1, 9, 0)],
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

    @Test("togglePill сбрасывает кэш целиком, а не только день слота")
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

    @Test("любая запись сбрасывает кэш, не только отметка дозы")
    func testAnyWriteInvalidatesTheCache() async throws {
        // Every write goes through commit(), which resets the cache — refill included.
        let db = DatabaseService(inMemoryForTesting: true)
        let med = makeCourseWithMed(db)

        #expect(db.fetchPills(for: testDate(2026, 6, 10)).first?.stockCount == 30)

        try db.refillStock(for: med, amount: 10)

        #expect(db.fetchPills(for: testDate(2026, 6, 10)).first?.stockCount == 40)
    }

    // MARK: - Change payload

    @Test("подписчик просыпается только на интересующие его области")
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

    @Test("запись объявляется в ленте своей базы, а не всем базам процесса")
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

    @Test("остаток не уходит в минус")
    func testStockNeverGoesNegative() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = makeCourseWithMed(db, stockCount: 1, dosage: 2)

        try db.togglePill(medicationId: med.id, scheduledTime: testDate(2026, 6, 10, 9, 0))

        #expect(med.stockCount == 0)
        #expect(med.logs.first?.status.isTaken == true)
    }

    @Test("доза прошедшего дня отмечается, actualTakeTime позже запланированного")
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
        let course = TreatmentCourse(name: "Курс", startDate: testDate(2026, 6, 1), endDate: testDate(2026, 6, 30))
        let med = MedicationItem(
            id: UUID(),
            name: "Аспирин",
            formSystemImage: "pills.fill",
            dosage: dosage,
            timesOfDay: [testDate(2000, 1, 1, 9, 0)],
            frequencyDays: 1,
            stockCount: stock,
            lowStockThreshold: 10
        )
        course.medications.append(med)
        db.context.insert(course)
        try? db.context.save()
        return med
    }

    @Test("отмена отметки при пустом остатке не создаёт таблетки")
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

    @Test("частичный остаток: возвращается ровно столько, сколько списалось")
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

    @Test("обычный случай не изменился: списалось и вернулось по полной дозе")
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

    @Test("смена дозировки после приёма не меняет возвращаемое количество")
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

    @Test("пропуск дозы остаток не трогает")
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

    @Test("передумал после пропуска: доза списывается как обычно")
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

    @Test("markDosesTaken пишет весь слот и не трогает уже принятую дозу")
    func testMarkDosesTakenIsIdempotentPerDose() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        let course = TreatmentCourse(name: "Курс", startDate: testDate(2026, 6, 1), endDate: testDate(2026, 6, 30))
        let times = [testDate(2000, 1, 1, 9, 0)]
        let first = MedicationItem(id: UUID(), name: "Аспирин", formSystemImage: "pills.fill", dosage: 2, timesOfDay: times, frequencyDays: 1, stockCount: 30, lowStockThreshold: 10)
        let second = MedicationItem(id: UUID(), name: "Магний", formSystemImage: "capsule.fill", dosage: 1, timesOfDay: times, frequencyDays: 1, stockCount: 10, lowStockThreshold: 5)
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

    @Test("markDosesTaken по уже закрытому слоту ничего не пишет")
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

    @Test("markDosesTaken поверх пропуска снимает пропуск и списывает остаток")
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

    @Test("unmarkDosesTaken возвращает списанное и не логирует непринятое")
    func testUnmarkDosesTakenOnlyReversesWhatWasLogged() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        let course = TreatmentCourse(name: "Курс", startDate: testDate(2026, 6, 1), endDate: testDate(2026, 6, 30))
        let times = [testDate(2000, 1, 1, 9, 0)]
        let logged = MedicationItem(id: UUID(), name: "Аспирин", formSystemImage: "pills.fill", dosage: 2, timesOfDay: times, frequencyDays: 1, stockCount: 30, lowStockThreshold: 10)
        let untouched = MedicationItem(id: UUID(), name: "Магний", formSystemImage: "capsule.fill", dosage: 1, timesOfDay: times, frequencyDays: 1, stockCount: 10, lowStockThreshold: 5)
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

    @Test("история доз, прочитанная в фоне, совпадает с чтением на главном потоке")
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
