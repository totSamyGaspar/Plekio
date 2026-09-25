//
//  AddMedicationViewModelTests.swift
//  PlekioTests
//
//  Tests for the add/edit medication draft — MedicationDraft.medicationImageData,
//  which carries a photo before DatabaseService writes it to disk.
//  Picking now happens in the view (PhotoSourceDialog), and the view model
//  receives the image through `attachPhoto(_:)`, which is async and can be
//  awaited. It used to call a picker service inside an unawaitable Task, so
//  this path had no tests at all.
//

import Testing
import SwiftUI
@testable import Plekio

@MainActor
@Suite("AddMedicationViewModel Tests")
struct AddMedicationViewModelTests {

    @Test("Initial state — an empty draft with no photo")
    func testInitialState() async throws {
        let vm = AddMedicationViewModel(photos: FakePhotoStore())

        #expect(vm.selectedImage == nil)
        #expect(vm.draft.medicationImageData == nil)
        #expect(vm.draft.photoModified == false)
        #expect(vm.showingPhotoSourceMenu == false)
    }

    @Test("removeImage clears both selectedImage and draft.medicationImageData")
    func testRemoveImageClearsBothImageAndDraft() async throws {
        let vm = AddMedicationViewModel(photos: FakePhotoStore())

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

    @Test("attachPhoto кладёт в черновик сжатый JPEG и помечает фото изменённым")
    func attachPhotoEncodesIntoTheDraft() async throws {
        let vm = AddMedicationViewModel(photos: FakePhotoStore())
        let image = TestImages.solid()

        await vm.attachPhoto(image)

        #expect(vm.selectedImage === image)
        let data = try #require(vm.draft.medicationImageData)
        #expect(data.starts(with: [0xFF, 0xD8]))   // JPEG
        #expect(vm.draft.photoModified == true)
    }

    @Test("фото, которое нельзя закодировать, не прикрепляется")
    func unencodableImageIsNotAttached() async {
        let vm = AddMedicationViewModel(photos: FakePhotoStore())

        // No CGImage and no CIImage behind it: both jpegData and pngData give nil.
        await vm.attachPhoto(UIImage())

        #expect(vm.selectedImage == nil)
        #expect(vm.draft.medicationImageData == nil)
        #expect(vm.draft.photoModified == false)
    }
}
