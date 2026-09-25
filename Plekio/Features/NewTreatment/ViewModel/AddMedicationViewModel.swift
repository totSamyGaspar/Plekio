//
//  AddMedicationViewModel.swift
//  Plekio
//
//  Created by Edward Gasparian on 20.05.2026.
//

import Combine
import OSLog
import SwiftUI

@MainActor
final class AddMedicationViewModel: AddMedicationViewModelProtocol {

    // MARK: - Properties

    @Published var draft = MedicationDraft()
    @Published var selectedImage: UIImage?
    @Published var showingPhotoSourceMenu = false

    private let photos: any PhotoStoring
    private var hasLoadedEditedMedication = false

    // MARK: - Init

    init(photos: any PhotoStoring) {
        self.photos = photos
    }

    // MARK: - Editing

    func startEditing(_ medication: MedicationSnapshot) async {
        // .task can fire more than once — a second pass would wipe the user's edits.
        guard !hasLoadedEditedMedication else { return }
        hasLoadedEditedMedication = true

        draft = MedicationDraft(from: medication)

        // Disk read and decode off the main actor.
        let medicationId = medication.id
        let loaded = await Task.detached(priority: .userInitiated) { () -> (Data, UIImage)? in
            guard let data = self.photos.loadDataFromDisk(for: medicationId),
                  let image = UIImage(data: data) else { return nil }
            return (data, image)
        }.value

        guard let loaded else { return }
        selectedImage = loaded.1
        // `photoModified` stays false: preloading is not an edit.
        draft.medicationImageData = loaded.0
    }

    // MARK: - Photo

    func attachPhoto(_ image: UIImage) async {
        // Compressed off the main actor. pngData covers images with no CGImage,
        // for which jpegData returns nil.
        let compressedData = await Task.detached(priority: .userInitiated) {
            image.jpegData(compressionQuality: 0.7) ?? image.pngData()
        }.value

        guard let compressedData else {
            AppLog.media.error("Picked image could not be encoded; photo not attached")
            return
        }

        selectedImage = image
        draft.medicationImageData = compressedData
        draft.photoModified = true
    }

    func removeImage() {
        selectedImage = nil
        draft.medicationImageData = nil
        draft.photoModified = true
    }
}
