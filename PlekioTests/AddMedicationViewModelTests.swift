//
//  AddMedicationViewModelTests.swift
//  PlekioTests
//
//  Tests for the add/edit medication draft — MedicationDraft.medicationImageData,
//  which carries a photo before DatabaseService writes it to disk.
//  requestImageSelection(source:) is deliberately not tested: it calls the
//  picker inside Task { ... } with no structured way to await it, so a test
//  would need sleep() (flaky) or a production signature change. removeImage()
//  and the initial state are synchronous, so those are tested directly.
//

import Testing
import SwiftUI
@testable import Plekio

@MainActor
@Suite("AddMedicationViewModel Tests")
struct AddMedicationViewModelTests {

    @Test("Initial state — an empty draft with no photo")
    func testInitialState() async throws {
        let mockMedia = MockMediaPickerService()
        let vm = AddMedicationViewModel(mediaPickerService: mockMedia, photos: FakePhotoStore())

        #expect(vm.selectedImage == nil)
        #expect(vm.draft.medicationImageData == nil)
        #expect(vm.draft.photoModified == false)
        #expect(vm.showingPhotoSourceMenu == false)
    }

    @Test("removeImage clears both selectedImage and draft.medicationImageData")
    func testRemoveImageClearsBothImageAndDraft() async throws {
        let mockMedia = MockMediaPickerService()
        let vm = AddMedicationViewModel(mediaPickerService: mockMedia, photos: FakePhotoStore())

        // A photo already selected: the user just came back from the picker, or this
        // is the edit screen, where init(editingMedication:) preloaded the bytes.
        vm.selectedImage = UIImage(systemName: "pills.fill")
        vm.draft.medicationImageData = Data([0x01, 0x02])

        vm.removeImage()

        #expect(vm.selectedImage == nil)
        #expect(vm.draft.medicationImageData == nil)
        // Marks the removal as deliberate, so DatabaseService deletes the file
        // instead of reading the empty draft as "not loaded yet".
        #expect(vm.draft.photoModified == true)
    }
}
