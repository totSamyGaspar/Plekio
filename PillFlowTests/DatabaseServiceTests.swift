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
        #expect(pills.allSatisfy { $0.name == "Ибупрофен" && $0.dosage == "2 pcs" })
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

        // Day 0 (the course start itself) — should match.
        #expect(db.fetchPills(for: courseStart).count == 1)
        // Day 1 — not a multiple of 3 → no match.
        #expect(db.fetchPills(for: addingDays(1, to: courseStart)).isEmpty)
        // Day 2 — also not a multiple of 3 → no match.
        #expect(db.fetchPills(for: addingDays(2, to: courseStart)).isEmpty)
        // Day 3 — a multiple of 3 → matches again.
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

        // First "taken" toggle: creates a DoseLog and deducts stock.
        db.togglePill(medicationId: med.id, scheduledTime: scheduledTime)
        #expect(med.logs.count == 1)
        #expect(med.logs.first?.isTaken == true)
        #expect(med.stockCount == 28)

        // Toggling the same slot again reverts the mark and restores stock.
        db.togglePill(medicationId: med.id, scheduledTime: scheduledTime)
        #expect(med.logs.count == 1) // the same DoseLog is reused, not duplicated
        #expect(med.logs.first?.isTaken == false)
        #expect(med.stockCount == 30)
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

        db.refillStock(for: med, amount: 10)

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

        // Clean up regardless of whether the assertion below fails.
        defer { ImageCache.shared.deleteFromDisk(for: med.id) }

        var draftWithPhoto = MedicationDraft()
        draftWithPhoto.name = "Омега-3"
        let fakeJPEGBytes = Data([0xFF, 0xD8, 0xFF, 0x00, 0x01, 0x02])
        draftWithPhoto.medicationImageData = fakeJPEGBytes

        db.updateMedication(med, with: draftWithPhoto)
        #expect(ImageCache.shared.loadDataFromDisk(for: med.id) == fakeJPEGBytes)

        // Saving without a photo (draft.medicationImageData == nil) must
        // explicitly delete the file rather than leave a stale one on disk.
        var draftWithoutPhoto = MedicationDraft()
        draftWithoutPhoto.name = "Омега-3"
        db.updateMedication(med, with: draftWithoutPhoto)
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

        db.deleteMedication(med)

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

        db.deleteCourse(course)

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

        db.saveDiaryEntry(draft: draft)

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

        // Clean up the photo file written to disk.
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
        db.saveDiaryEntry(draft: original)

        let saved = try #require(db.fetchAllDiaryEntries().first)
        let oldPhotoId = try #require(saved.photoIds.first)
        #expect(ImageCache.shared.loadDataFromDisk(for: oldPhotoId) != nil)

        var updatedDraft = DiaryEntryDraft()
        updatedDraft.mood = .inPain
        updatedDraft.physicalSummary = "Worse today."
        updatedDraft.photos = [Data([0x02])]
        // Mirrors DiaryCheckInViewModel.requestImageSelection/removePhoto
        // actually setting this when the user touches photos.
        updatedDraft.photosModified = true

        db.updateDiaryEntry(saved, with: updatedDraft)

        #expect(saved.moodLabel == "In Pain")
        #expect(saved.moodScore == 1)
        #expect(saved.physicalSummary == "Worse today.")
        #expect(saved.photoIds.count == 1)

        let newPhotoId = try #require(saved.photoIds.first)
        #expect(newPhotoId != oldPhotoId)
        #expect(ImageCache.shared.loadDataFromDisk(for: newPhotoId) == Data([0x02]))
        // The old photo file must be cleaned up, not left orphaned.
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
        db.saveDiaryEntry(draft: original)

        let saved = try #require(db.fetchAllDiaryEntries().first)
        let originalPhotoId = try #require(saved.photoIds.first)

        // Simulates DiaryCheckInView.init(editingEntry:) preloading the
        // existing photo bytes into the draft (photosModified stays false
        // since the user never called requestImageSelection/removePhoto),
        // then saving after only changing an unrelated field.
        var updatedDraft = DiaryEntryDraft()
        updatedDraft.mood = .inPain
        updatedDraft.photos = [Data([0x01])] // same bytes, preloaded, untouched

        db.updateDiaryEntry(saved, with: updatedDraft)

        #expect(saved.moodLabel == "In Pain")
        // The photo id must be exactly the same file — not deleted and
        // rewritten under a new UUID for no reason.
        #expect(saved.photoIds == [originalPhotoId])
        #expect(ImageCache.shared.loadDataFromDisk(for: originalPhotoId) == Data([0x01]))

        ImageCache.shared.deleteFromDisk(for: originalPhotoId)
    }

    @Test("deleteDiaryEntry removes the entry's photo files from disk")
    func testDeleteDiaryEntryRemovesPhotoFiles() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        var draft = DiaryEntryDraft()
        draft.photos = [Data([0x01]), Data([0x02])]
        db.saveDiaryEntry(draft: draft)

        let saved = try #require(db.fetchAllDiaryEntries().first)
        let photoIds = saved.photoIds
        #expect(photoIds.count == 2)
        #expect(photoIds.allSatisfy { ImageCache.shared.loadDataFromDisk(for: $0) != nil })

        db.deleteDiaryEntry(saved)

        #expect(db.fetchAllDiaryEntries().isEmpty)
        #expect(photoIds.allSatisfy { ImageCache.shared.loadDataFromDisk(for: $0) == nil })
    }
}
