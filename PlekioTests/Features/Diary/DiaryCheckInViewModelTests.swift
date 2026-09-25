//
//  DiaryCheckInViewModelTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.08.2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Plekio

@MainActor
@Suite("DiaryCheckInViewModel Tests")
struct DiaryCheckInViewModelTests {

    // MARK: - Draft editing

    @Test("Initial state — default draft, no photos")
    func testInitialState() async throws {
        let mockDb = MockDatabaseService()
        let vm = DiaryCheckInViewModel(dbService: mockDb, photos: FakePhotoStore(), errors: SpyErrorReporter())

        #expect(vm.draft.mood == .good)
        #expect(vm.draft.symptoms.isEmpty)
        #expect(vm.draft.milestoneTags.isEmpty)
        #expect(vm.selectedImages.isEmpty)
    }

    @Test("attachPhoto добавляет фото к записи, removePhoto убирает его")
    func attachThenRemovePhoto() async {
        let vm = DiaryCheckInViewModel(dbService: MockDatabaseService(), photos: FakePhotoStore(), errors: SpyErrorReporter())

        await vm.attachPhoto(TestImages.solid())
        await vm.attachPhoto(TestImages.solid())

        #expect(vm.selectedImages.count == 2)
        #expect(vm.draft.photos.count == 2)
        #expect(vm.draft.photosModified)

        vm.removePhoto(at: 0)
        #expect(vm.selectedImages.count == 1)
        #expect(vm.draft.photos.count == 1)
    }

    @Test("toggleSymptom adds then removes a symptom")
    func testToggleSymptomAddsAndRemoves() async throws {
        let vm = DiaryCheckInViewModel(dbService: MockDatabaseService(), photos: FakePhotoStore(), errors: SpyErrorReporter())

        vm.toggleSymptom("Headache")
        #expect(vm.draft.symptoms == ["Headache"])

        vm.toggleSymptom("Headache")
        #expect(vm.draft.symptoms.isEmpty)
    }

    @Test("addCustomSymptom trims whitespace and ignores blank/duplicate input")
    func testAddCustomSymptomTrimsAndDedupes() async throws {
        let vm = DiaryCheckInViewModel(dbService: MockDatabaseService(), photos: FakePhotoStore(), errors: SpyErrorReporter())

        vm.addCustomSymptom("  Neck pain  ")
        #expect(vm.draft.symptoms == ["Neck pain"])

        vm.addCustomSymptom("Neck pain")
        #expect(vm.draft.symptoms == ["Neck pain"])

        vm.addCustomSymptom("   ")
        #expect(vm.draft.symptoms == ["Neck pain"])
    }

    @Test("toggleMilestone adds then removes a tag")
    func testToggleMilestoneAddsAndRemoves() async throws {
        let vm = DiaryCheckInViewModel(dbService: MockDatabaseService(), photos: FakePhotoStore(), errors: SpyErrorReporter())

        vm.toggleMilestone("Morning Walk")
        #expect(vm.draft.milestoneTags == ["Morning Walk"])

        vm.toggleMilestone("Morning Walk")
        #expect(vm.draft.milestoneTags.isEmpty)
    }

    @Test("removePhoto keeps selectedImages and draft.photos in sync")
    func testRemovePhotoKeepsArraysInSync() async throws {
        let vm = DiaryCheckInViewModel(dbService: MockDatabaseService(), photos: FakePhotoStore(), errors: SpyErrorReporter())

        vm.selectedImages = [UIImage(systemName: "pills.fill")!, UIImage(systemName: "drop.fill")!]
        vm.draft.photos = [Data([0x01]), Data([0x02])]

        vm.removePhoto(at: 0)

        #expect(vm.selectedImages.count == 1)
        #expect(vm.draft.photos == [Data([0x02])])
    }

    // MARK: - Saving and editing entries

    @Test("save() delegates the current draft to DatabaseServiceProtocol")
    func testSaveDelegatesToDatabaseService() async throws {
        let mockDb = MockDatabaseService()
        let vm = DiaryCheckInViewModel(dbService: mockDb, photos: FakePhotoStore(), errors: SpyErrorReporter())

        vm.draft.physicalSummary = "Feeling steady today."
        vm.save()

        #expect(mockDb.savedDiaryDraft?.physicalSummary == "Feeling steady today.")
        #expect(mockDb.updatedDiaryEntry == nil)
    }

    @Test("startEditing переносит ВСЕ поля записи в черновик, включая isQuickLog")
    func testStartEditingCopiesEveryField() async throws {
        let mockDb = MockDatabaseService()
        let vm = DiaryCheckInViewModel(dbService: mockDb, photos: FakePhotoStore(), errors: SpyErrorReporter())

        // Quick log: energy/sleep/water are draft defaults, not user input.
        let quickEntry = DiaryEntry(
            checkInDate: testDate(2026, 7, 3, 8, 30),
            moodLabel: DiaryMood.exhausted.rawValue,
            moodScore: DiaryMood.exhausted.score,
            physicalSummary: "",
            energyLevel: 4,
            discomfortLevel: 0,
            sleepHours: 7.5,
            sleepQuality: SleepQuality.good.rawValue,
            waterGlasses: 6,
            symptoms: [],
            reflectionNotes: "",
            milestoneTags: [],
            isQuickLog: true
        )

        await vm.startEditing(DiaryEntrySnapshot(quickEntry))

        // Losing the flag would turn the defaults into invented user data.
        #expect(vm.draft.isQuickLog == true)

        #expect(vm.draft.id == quickEntry.id)
        #expect(vm.draft.mood == .exhausted)
        #expect(vm.draft.checkInDate == quickEntry.checkInDate)
        #expect(vm.draft.photosModified == false)
    }

    @Test("правка быстрой записи сохраняет её быстрой")
    func testEditingQuickLogKeepsFlagOnSave() async throws {
        let mockDb = MockDatabaseService()
        let vm = DiaryCheckInViewModel(dbService: mockDb, photos: FakePhotoStore(), errors: SpyErrorReporter())

        let quickEntry = DiaryEntry(
            checkInDate: Date(),
            moodLabel: DiaryMood.good.rawValue,
            moodScore: 4,
            physicalSummary: "",
            energyLevel: 4,
            discomfortLevel: 0,
            sleepHours: 7.5,
            sleepQuality: SleepQuality.good.rawValue,
            waterGlasses: 6,
            symptoms: [],
            reflectionNotes: "",
            milestoneTags: [],
            isQuickLog: true
        )

        mockDb.diaryEntriesToReturn = [quickEntry]
        await vm.startEditing(DiaryEntrySnapshot(quickEntry))
        vm.draft.mood = .great
        vm.save()

        #expect(mockDb.updatedDiaryDraft?.isQuickLog == true)
    }

    // MARK: - Draft bounds

    @Test("черновик держит числовые поля в допустимых границах")
    func testDraftClampsNumericFields() async throws {
        var draft = DiaryEntryDraft()

        draft.sleepHours = 99
        #expect(draft.sleepHours == 24)
        draft.sleepHours = -3
        #expect(draft.sleepHours == 0)

        draft.waterGlasses = -1
        #expect(draft.waterGlasses == 0)
        draft.waterGlasses = 9_999
        #expect(draft.waterGlasses == DiaryEntryDraft.waterGlassesRange.upperBound)

        draft.energyLevel = 0
        #expect(draft.energyLevel == 1)
        draft.energyLevel = 42
        #expect(draft.energyLevel == 5)

        draft.discomfortLevel = -5
        #expect(draft.discomfortLevel == 0)
        draft.discomfortLevel = 11
        #expect(draft.discomfortLevel == 10)
    }

    @Test("значения из хранилища тоже попадают в границы")
    func testDraftClampsValuesLoadedFromStorage() async throws {
        // didSet does not run in init(from:), so it must clamp stored values itself.
        let entry = DiaryEntry(
            checkInDate: testDate(2026, 6, 15),
            moodLabel: "Good",
            moodScore: 4,
            physicalSummary: "",
            energyLevel: 99,
            discomfortLevel: -4,
            sleepHours: 48,
            sleepQuality: "G",
            waterGlasses: -2,
            symptoms: [],
            reflectionNotes: "",
            milestoneTags: [],
            photoIds: []
        )

        let draft = DiaryEntryDraft(from: DiaryEntrySnapshot(entry))

        #expect(draft.energyLevel == 5)
        #expect(draft.discomfortLevel == 0)
        #expect(draft.sleepHours == 24)
        #expect(draft.waterGlasses == 0)
    }

    // MARK: - Updating an entry

    @Test("save() updates the existing entry instead of creating a new one when editing")
    func testSaveUpdatesExistingEntryWhenEditing() async throws {
        let mockDb = MockDatabaseService()
        let vm = DiaryCheckInViewModel(dbService: mockDb, photos: FakePhotoStore(), errors: SpyErrorReporter())

        let existingEntry = DiaryEntry(
            checkInDate: Date(),
            moodLabel: DiaryMood.good.rawValue,
            moodScore: 4,
            physicalSummary: "",
            energyLevel: 3,
            discomfortLevel: 0,
            sleepHours: 7,
            sleepQuality: SleepQuality.fair.rawValue,
            waterGlasses: 4,
            symptoms: [],
            reflectionNotes: "",
            milestoneTags: []
        )
        mockDb.diaryEntriesToReturn = [existingEntry]
        await vm.startEditing(DiaryEntrySnapshot(existingEntry))
        vm.draft.physicalSummary = "Updated summary."

        vm.save()

        #expect(mockDb.updatedDiaryEntry === existingEntry)
        #expect(mockDb.updatedDiaryDraft?.physicalSummary == "Updated summary.")
        #expect(mockDb.savedDiaryDraft == nil)
    }
}
