//
//  DiaryCheckInViewModelTests.swift
//  PillFlowTests
//
//  Tests for the diary check-in draft's tag toggling/dedup logic and for
//  save() correctly delegating to DatabaseServiceProtocol. Photo selection via
//  requestImageSelection(source:) is intentionally NOT tested here, for the
//  same reason as AddMedicationViewModelTests: it awaits an async picker call
//  inside Task { ... } without a structured way to await it from a test.
//

import Testing
import Foundation
import SwiftUI
@testable import PillFlow

@MainActor
@Suite("DiaryCheckInViewModel Tests")
struct DiaryCheckInViewModelTests {

    @Test("Initial state — default draft, no photos")
    func testInitialState() async throws {
        let mockDb = MockDatabaseService()
        let mockMedia = MockMediaPickerService()
        let vm = DiaryCheckInViewModel(dbService: mockDb, mediaPickerService: mockMedia)

        #expect(vm.draft.mood == .good)
        #expect(vm.draft.symptoms.isEmpty)
        #expect(vm.draft.milestoneTags.isEmpty)
        #expect(vm.selectedImages.isEmpty)
    }

    @Test("toggleSymptom adds then removes a symptom")
    func testToggleSymptomAddsAndRemoves() async throws {
        let vm = DiaryCheckInViewModel(dbService: MockDatabaseService(), mediaPickerService: MockMediaPickerService())

        vm.toggleSymptom("Headache")
        #expect(vm.draft.symptoms == ["Headache"])

        vm.toggleSymptom("Headache")
        #expect(vm.draft.symptoms.isEmpty)
    }

    @Test("addCustomSymptom trims whitespace and ignores blank/duplicate input")
    func testAddCustomSymptomTrimsAndDedupes() async throws {
        let vm = DiaryCheckInViewModel(dbService: MockDatabaseService(), mediaPickerService: MockMediaPickerService())

        vm.addCustomSymptom("  Neck pain  ")
        #expect(vm.draft.symptoms == ["Neck pain"])

        // Duplicate (already present) — ignored.
        vm.addCustomSymptom("Neck pain")
        #expect(vm.draft.symptoms == ["Neck pain"])

        // Blank input — ignored.
        vm.addCustomSymptom("   ")
        #expect(vm.draft.symptoms == ["Neck pain"])
    }

    @Test("toggleMilestone adds then removes a tag")
    func testToggleMilestoneAddsAndRemoves() async throws {
        let vm = DiaryCheckInViewModel(dbService: MockDatabaseService(), mediaPickerService: MockMediaPickerService())

        vm.toggleMilestone("Morning Walk")
        #expect(vm.draft.milestoneTags == ["Morning Walk"])

        vm.toggleMilestone("Morning Walk")
        #expect(vm.draft.milestoneTags.isEmpty)
    }

    @Test("removePhoto keeps selectedImages and draft.photos in sync")
    func testRemovePhotoKeepsArraysInSync() async throws {
        let vm = DiaryCheckInViewModel(dbService: MockDatabaseService(), mediaPickerService: MockMediaPickerService())

        vm.selectedImages = [UIImage(systemName: "pills.fill")!, UIImage(systemName: "drop.fill")!]
        vm.draft.photos = [Data([0x01]), Data([0x02])]

        vm.removePhoto(at: 0)

        #expect(vm.selectedImages.count == 1)
        #expect(vm.draft.photos == [Data([0x02])])
    }

    @Test("save() delegates the current draft to DatabaseServiceProtocol")
    func testSaveDelegatesToDatabaseService() async throws {
        let mockDb = MockDatabaseService()
        let vm = DiaryCheckInViewModel(dbService: mockDb, mediaPickerService: MockMediaPickerService())

        vm.draft.physicalSummary = "Feeling steady today."
        vm.save()

        #expect(mockDb.savedDiaryDraft?.physicalSummary == "Feeling steady today.")
        #expect(mockDb.updatedDiaryEntry == nil) // no editingEntry set → this is a create, not an update
    }

    @Test("save() updates the existing entry instead of creating a new one when editing")
    func testSaveUpdatesExistingEntryWhenEditing() async throws {
        let mockDb = MockDatabaseService()
        let vm = DiaryCheckInViewModel(dbService: mockDb, mediaPickerService: MockMediaPickerService())

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
        vm.editingEntry = existingEntry
        vm.draft.physicalSummary = "Updated summary."

        vm.save()

        #expect(mockDb.updatedDiaryEntry === existingEntry)
        #expect(mockDb.updatedDiaryDraft?.physicalSummary == "Updated summary.")
        #expect(mockDb.savedDiaryDraft == nil) // must not also create a new entry
    }
}
