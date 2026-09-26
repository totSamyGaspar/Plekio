//
//  AddMedicationViewModelTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 22.08.2026.
//

import Testing
import SwiftUI
@testable import Plekio

@MainActor
@Suite("AddMedicationViewModel Tests")
struct AddMedicationViewModelTests {

    // MARK: - Initial state

    @Test("Initial state — an empty draft with no photo")
    func testInitialState() async throws {
        let vm = AddMedicationViewModel(photos: FakePhotoStore())

        #expect(vm.selectedImage == nil)
        #expect(vm.draft.medicationImageData == nil)
        #expect(vm.draft.photoModified == false)
        #expect(vm.showingPhotoSourceMenu == false)
    }

    // MARK: - Photo

    @Test("removeImage clears both selectedImage and draft.medicationImageData")
    func testRemoveImageClearsBothImageAndDraft() async throws {
        let vm = AddMedicationViewModel(photos: FakePhotoStore())

        vm.selectedImage = UIImage(systemName: "pills.fill")
        vm.draft.medicationImageData = Data([0x01, 0x02])

        vm.removeImage()

        #expect(vm.selectedImage == nil)
        #expect(vm.draft.medicationImageData == nil)
        // Marks the removal as deliberate, so the stored file is deleted rather than kept.
        #expect(vm.draft.photoModified == true)
    }

    @Test("attachPhoto puts a compressed JPEG into the draft and marks photos modified")
    func attachPhotoEncodesIntoTheDraft() async throws {
        let vm = AddMedicationViewModel(photos: FakePhotoStore())
        let image = TestImages.solid()

        await vm.attachPhoto(image)

        #expect(vm.selectedImage === image)
        let data = try #require(vm.draft.medicationImageData)
        #expect(data.starts(with: [0xFF, 0xD8]))
        #expect(vm.draft.photoModified == true)
    }

    @Test("A photo that can't be encoded isn't attached")
    func unencodableImageIsNotAttached() async {
        let vm = AddMedicationViewModel(photos: FakePhotoStore())

        // No CGImage or CIImage behind it, so encoding returns nil.
        await vm.attachPhoto(UIImage())

        #expect(vm.selectedImage == nil)
        #expect(vm.draft.medicationImageData == nil)
        #expect(vm.draft.photoModified == false)
    }
}
