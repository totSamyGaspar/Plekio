//
//  AddMedicationViewModelTests.swift
//  PillFlowTests
//
//  Tests for the add/edit medication draft — MedicationDraft.medicationImageData,
//  which carries a photo before DatabaseService writes it to disk.
//  requestImageSelection(source:) is intentionally NOT tested here: it calls
//  MediaPickerServiceProtocol asynchronously via Task { ... }, and without
//  structured awaiting of that task, testing it would mean either sleep()
//  (flaky) or changing the production protocol's signature just for
//  testability — not worth it for a single test. removeImage() and the
//  initial state are synchronous and deterministic, so those are tested directly.
//

import Testing
import SwiftUI
@testable import PillFlow

@MainActor
@Suite("AddMedicationViewModel Tests")
struct AddMedicationViewModelTests {

    @Test("Initial state — an empty draft with no photo")
    func testInitialState() async throws {
        let mockMedia = MockMediaPickerService()
        let vm = AddMedicationViewModel(mediaPickerService: mockMedia)

        #expect(vm.selectedImage == nil)
        #expect(vm.draft.medicationImageData == nil)
        #expect(vm.showingPhotoSourceMenu == false)
    }

    @Test("removeImage clears both selectedImage and draft.medicationImageData")
    func testRemoveImageClearsBothImageAndDraft() async throws {
        let mockMedia = MockMediaPickerService()
        let vm = AddMedicationViewModel(mediaPickerService: mockMedia)

        // Simulate a photo already having been selected (as if the user just
        // returned from the picker, or this is the edit screen where
        // AddMedicationView.init(editingMedication:) loaded bytes from disk).
        vm.selectedImage = UIImage(systemName: "pills.fill")
        vm.draft.medicationImageData = Data([0x01, 0x02])

        vm.removeImage()

        #expect(vm.selectedImage == nil)
        #expect(vm.draft.medicationImageData == nil)
    }
}
