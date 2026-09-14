//
//  DatabaseServiceTests.swift
//  PillFlowTests
//
//  Tests for DatabaseService: dose fetching, stock tracking, and photo
//  persistence to disk. DatabaseService(inMemoryForTesting: true) provides an
//  independent in-memory container with the same schema, so these tests don't
//  touch the app's real disk-backed data.
//

import Testing
import Foundation
import SwiftData
@testable import PillFlow

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

        // frequencyDays 3, counted from the course start: days 0 and 3 are multiples
        // of the interval and match, days 1 and 2 are not.
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
        #expect(med.logs.first?.isTaken == true)
        #expect(med.stockCount == 28)

        try db.togglePill(medicationId: med.id, scheduledTime: scheduledTime)
        #expect(med.logs.count == 1) // the same DoseLog is reused, not duplicated
        #expect(med.logs.first?.isTaken == false)
        #expect(med.stockCount == 30)
    }

    @Test("сдвиг времени приёма переносит уже поставленные отметки")
    func testChangingScheduleMovesExistingLogs() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = makeCourseWithMed(db)
        let day = testDate(2026, 6, 10)

        try db.togglePill(medicationId: med.id, scheduledTime: testDate(2026, 6, 10, 9, 0))
        #expect(db.fetchPills(for: day).first?.isTaken == true)

        // Move the dose to 11:00. The log used to stay pinned to 9:00 where the
        // schedule no longer looked for it, so the day read as unlogged even though
        // the stock had already been deducted.
        var draft = MedicationDraft(from: med)
        draft.timesOfDay = [testDate(2000, 1, 1, 11, 0)]
        try db.updateMedication(med, with: draft)

        let pills = db.fetchPills(for: day)
        #expect(pills.count == 1)
        #expect(pills.first?.isTaken == true)
        #expect(Calendar.current.component(.hour, from: try #require(pills.first).time) == 11)
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

        // ImageCache writes to the real on-disk cache, not a temp dir, so a leftover
        // file would leak into the next test run.
        defer { ImageCache.shared.deleteFromDisk(for: med.id) }

        var draftWithPhoto = MedicationDraft()
        draftWithPhoto.name = "Омега-3"
        let fakeJPEGBytes = Data([0xFF, 0xD8, 0xFF, 0x00, 0x01, 0x02])
        draftWithPhoto.medicationImageData = fakeJPEGBytes
        draftWithPhoto.photoModified = true

        try db.updateMedication(med, with: draftWithPhoto)
        #expect(ImageCache.shared.loadDataFromDisk(for: med.id) == fakeJPEGBytes)

        // An edit that never touched the photo must leave the file alone, even
        // though the draft carries no bytes — the preload may simply not have
        // finished. This is what used to erase photos on a rename.
        var renameOnly = MedicationDraft()
        renameOnly.name = "Омега-3 форте"
        try db.updateMedication(med, with: renameOnly)
        #expect(ImageCache.shared.loadDataFromDisk(for: med.id) == fakeJPEGBytes)

        // Removing the photo (photoModified with no bytes) must delete the file,
        // not leave a stale one on disk.
        var draftWithoutPhoto = MedicationDraft()
        draftWithoutPhoto.name = "Омега-3"
        draftWithoutPhoto.photoModified = true
        try db.updateMedication(med, with: draftWithoutPhoto)
        #expect(ImageCache.shared.loadDataFromDisk(for: med.id) == nil)
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
        ImageCache.shared.saveToDisk(Data([0x01]), for: med.id)
        #expect(ImageCache.shared.loadDataFromDisk(for: med.id) != nil)

        try db.deleteMedication(med)

        #expect(ImageCache.shared.loadDataFromDisk(for: med.id) == nil)
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

        ImageCache.shared.saveToDisk(Data([0x01]), for: medA.id)
        ImageCache.shared.saveToDisk(Data([0x02]), for: medB.id)

        try db.deleteCourse(course)

        #expect(ImageCache.shared.loadDataFromDisk(for: medA.id) == nil)
        #expect(ImageCache.shared.loadDataFromDisk(for: medB.id) == nil)
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
            #expect(ImageCache.shared.loadDataFromDisk(for: photoId) == Data([0xFF, 0xD8, 0xFF]))
            ImageCache.shared.deleteFromDisk(for: photoId)
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
        #expect(ImageCache.shared.loadDataFromDisk(for: oldPhotoId) != nil)

        var updatedDraft = DiaryEntryDraft()
        updatedDraft.mood = .inPain
        updatedDraft.physicalSummary = "Worse today."
        updatedDraft.photos = [Data([0x02])]
        // DiaryCheckInViewModel.requestImageSelection/removePhoto set this whenever
        // the user actually touches photos.
        updatedDraft.photosModified = true

        try db.updateDiaryEntry(saved, with: updatedDraft)

        #expect(saved.moodLabel == "In Pain")
        #expect(saved.moodScore == 1)
        #expect(saved.physicalSummary == "Worse today.")
        #expect(saved.photoIds.count == 1)

        let newPhotoId = try #require(saved.photoIds.first)
        #expect(newPhotoId != oldPhotoId)
        #expect(ImageCache.shared.loadDataFromDisk(for: newPhotoId) == Data([0x02]))
        #expect(ImageCache.shared.loadDataFromDisk(for: oldPhotoId) == nil)

        ImageCache.shared.deleteFromDisk(for: newPhotoId)
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

        // DiaryCheckInView.init(editingEntry:) preloads the existing photo bytes into
        // the draft; photosModified stays false because the user never touched the
        // photos, and only an unrelated field is changed before saving.
        var updatedDraft = DiaryEntryDraft()
        updatedDraft.mood = .inPain
        updatedDraft.photos = [Data([0x01])] // same bytes, preloaded, untouched

        try db.updateDiaryEntry(saved, with: updatedDraft)

        #expect(saved.moodLabel == "In Pain")
        // The same file, not deleted and rewritten under a fresh UUID.
        #expect(saved.photoIds == [originalPhotoId])
        #expect(ImageCache.shared.loadDataFromDisk(for: originalPhotoId) == Data([0x01]))

        ImageCache.shared.deleteFromDisk(for: originalPhotoId)
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
        #expect(photoIds.allSatisfy { ImageCache.shared.loadDataFromDisk(for: $0) != nil })

        try db.deleteDiaryEntry(saved)

        #expect(db.fetchAllDiaryEntries().isEmpty)
        #expect(photoIds.allSatisfy { ImageCache.shared.loadDataFromDisk(for: $0) == nil })
    }

    // MARK: - togglePill: back-dated logging

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

    @Test("togglePill сбрасывает кэш целиком, а не только день слота")
    func testTogglePillInvalidatesCacheForAllDays() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = makeCourseWithMed(db)

        // Warm the cache for a different day: the cached entry copies stockCount as
        // it stood at that fetch.
        let otherDay = testDate(2026, 6, 10)
        #expect(db.fetchPills(for: otherDay).first?.stockCount == 30)

        // Log a dose on the NEIGHBOURING day. Stock is shared across days, so the
        // cached day has to see the new value.
        try db.togglePill(medicationId: med.id, scheduledTime: testDate(2026, 6, 11, 9, 0))

        #expect(db.fetchPills(for: otherDay).first?.stockCount == 28)
    }

    @Test("любая запись сбрасывает кэш, не только отметка дозы")
    func testAnyWriteInvalidatesTheCache() async throws {
        // The invalidation moved out of the mutating methods and into commit(),
        // which every write goes through. This is the half that was easy to forget
        // when each method had to remember for itself: refillStock is not about
        // doses at all, but the cached PillDose carries a copy of the stock.
        let db = DatabaseService(inMemoryForTesting: true)
        let med = makeCourseWithMed(db)

        #expect(db.fetchPills(for: testDate(2026, 6, 10)).first?.stockCount == 30)

        try db.refillStock(for: med, amount: 10)

        #expect(db.fetchPills(for: testDate(2026, 6, 10)).first?.stockCount == 40)
    }

    // MARK: - Change payload

    @Test("подписчик просыпается только на интересующие его области")
    func testChangePayloadMatching() async throws {
        func notification(_ changes: Set<DatabaseChange>) -> Notification {
            Notification(
                name: .databaseDidChange,
                object: nil,
                userInfo: [DatabaseChange.userInfoKey: changes]
            )
        }

        // A diary write must not wake the dashboard, the course list or the
        // statistics — that re-fetch on every unrelated write is what the payload
        // exists to stop.
        #expect(notification([.diary]).touchesDatabase([.courses, .doses]) == false)
        #expect(notification([.diary]).touchesDatabase([.diary]) == true)

        // A logged dose must not send every visible medication photo back to disk.
        #expect(notification([.doses]).touchesDatabase([.courses]) == false)
        #expect(notification([.doses]).touchesDatabase([.courses, .doses]) == true)

        // Partial overlap is enough.
        #expect(notification([.courses, .diary]).touchesDatabase([.doses, .diary]) == true)

        // No payload means "assume everything changed".
        #expect(Notification(name: .databaseDidChange).touchesDatabase([.courses]) == true)
    }

    @Test("остаток не уходит в минус")
    func testStockNeverGoesNegative() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = makeCourseWithMed(db, stockCount: 1, dosage: 2)

        try db.togglePill(medicationId: med.id, scheduledTime: testDate(2026, 6, 10, 9, 0))

        #expect(med.stockCount == 0)
        #expect(med.logs.first?.isTaken == true)
    }

    @Test("доза прошедшего дня отмечается, actualTakeTime позже запланированного")
    func testLateLoggingRecordsActualTime() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = makeCourseWithMed(db)

        let scheduled = testDate(2026, 6, 10, 9, 0)
        try db.togglePill(medicationId: med.id, scheduledTime: scheduled)

        let log = try #require(med.logs.first)
        #expect(log.isTaken == true)
        #expect(log.scheduledTime == scheduled)
        // Logged now against a slot in the past, so the delay is visible in the log
        // itself and needs no separate field.
        let actualTakeTime = try #require(log.actualTakeTime)
        #expect(actualTakeTime > scheduled)

        #expect(db.fetchPills(for: testDate(2026, 6, 10)).first?.isTaken == true)
    }

    // MARK: - Stock accounting at the bottom of the bottle
    //
    // Stock is clamped at zero, so a dose logged with a nearly empty bottle takes
    // out less than a full dose. Undo used to credit back the full dosage anyway,
    // which invented pills: log at zero stock, undo, and the bottle had refilled
    // itself. DoseLog now records what actually left, and undo returns that.

    /// One medication in a live in-memory store, with the stock and dosage a test
    /// cares about. The surrounding course is scaffolding.
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
        // Nothing left the bottle, and that is what is written down.
        #expect(med.logs.first?.dispensedQuantity == 0)

        try db.togglePill(medicationId: med.id, scheduledTime: slot)
        #expect(med.stockCount == 0)   // was 2 before the fix
        #expect(med.logs.first?.dispensedQuantity == nil)
    }

    @Test("частичный остаток: возвращается ровно столько, сколько списалось")
    func testUndoReturnsExactlyWhatWasDispensed() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = medication(stock: 1, dosage: 2, in: db)
        let slot = testDate(2026, 6, 10, 9, 0)

        // One tablet for a two-tablet dose: the bottle only had one.
        try db.togglePill(medicationId: med.id, scheduledTime: slot)
        #expect(med.stockCount == 0)
        #expect(med.logs.first?.dispensedQuantity == 1)

        try db.togglePill(medicationId: med.id, scheduledTime: slot)
        #expect(med.stockCount == 1)   // was 2 before the fix
    }

    @Test("обычный случай не изменился: списалось и вернулось по полной дозе")
    func testFullDoseRoundTripIsUnchanged() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = medication(stock: 10, dosage: 2, in: db)
        let slot = testDate(2026, 6, 10, 9, 0)

        try db.togglePill(medicationId: med.id, scheduledTime: slot)
        #expect(med.stockCount == 8)
        #expect(med.logs.first?.dispensedQuantity == 2)

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

        // The user edits the course afterwards: a dose is five tablets now.
        med.dosage = 5
        try? db.context.save()

        // Two went out, so two come back — not today's five.
        try db.togglePill(medicationId: med.id, scheduledTime: slot)
        #expect(med.stockCount == 10)
    }

    @Test("пропуск дозы остаток не трогает")
    func testSkipLeavesStockAlone() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = medication(stock: 10, dosage: 2, in: db)
        let slot = testDate(2026, 6, 10, 9, 0)

        try db.skipDoses(medicationIds: [med.id], scheduledTime: slot)

        // Nothing was swallowed, so nothing left the bottle — and the log says so
        // rather than recording a zero dispense, which would mean "taken, but the
        // bottle was empty".
        #expect(med.stockCount == 10)
        #expect(med.logs.first?.skippedAt != nil)
        #expect(med.logs.first?.isTaken == false)
        #expect(med.logs.first?.dispensedQuantity == nil)
    }

    @Test("передумал после пропуска: доза списывается как обычно")
    func testTakingAfterASkipDeductsStock() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let med = medication(stock: 10, dosage: 2, in: db)
        let slot = testDate(2026, 6, 10, 9, 0)

        try db.skipDoses(medicationIds: [med.id], scheduledTime: slot)
        try db.togglePill(medicationId: med.id, scheduledTime: slot)

        #expect(med.logs.count == 1)   // the skip's log is reused, not duplicated
        #expect(med.logs.first?.isTaken == true)
        #expect(med.logs.first?.skippedAt == nil)
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

        // The first one is logged by hand before the group write.
        try db.togglePill(medicationId: first.id, scheduledTime: slot)
        #expect(first.stockCount == 28)

        try db.markDosesTaken(medicationIds: [first.id, second.id], scheduledTime: slot)

        // The already-logged one is untouched — not toggled off, not deducted twice.
        #expect(first.logs.count == 1)
        #expect(first.logs.first?.isTaken == true)
        #expect(first.stockCount == 28)

        #expect(second.logs.count == 1)
        #expect(second.logs.first?.isTaken == true)
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

        // A second press of "Take Now" must not deduct again, and must not create
        // a second log for the same occurrence.
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
        #expect(med.logs.first?.isTaken == true)
        #expect(med.logs.first?.skippedAt == nil)
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

        #expect(logged.logs.first?.isTaken == false)
        #expect(logged.logs.first?.dispensedQuantity == nil)
        #expect(logged.stockCount == 30)

        // The one that was never logged gains nothing: an undo can only un-log.
        #expect(untouched.logs.isEmpty)
        #expect(untouched.stockCount == 10)
    }
}
