//
//  AddMedicationViewModel.swift
//  PillFlow
//
//  Created by Edward Gasparian on 20.05.2026.
//

import Combine
import OSLog
import SwiftUI

@MainActor
final class AddMedicationViewModel: AddMedicationViewModelProtocol {
    @Published var draft = MedicationDraft()
    @Published var selectedImage: UIImage?
    @Published var showingPhotoSourceMenu = false
    
    private let mediaPickerService: MediaPickerServiceProtocol
    private var hasLoadedEditedMedication = false

    init(mediaPickerService: MediaPickerServiceProtocol) {
        self.mediaPickerService = mediaPickerService
    }

    // MARK: - Editing

    func startEditing(_ medication: MedicationItem) async {
        // .task can fire more than once — a second pass would wipe the user's edits.
        guard !hasLoadedEditedMedication else { return }
        hasLoadedEditedMedication = true

        draft = MedicationDraft(from: medication)

        // The photo used to be read from disk synchronously inside the view's init:
        // on the main thread, and again on every re-creation of the view struct.
        let medicationId = medication.id
        let loaded = await Task.detached(priority: .userInitiated) { () -> (Data, UIImage)? in
            guard let data = ImageCache.shared.loadDataFromDisk(for: medicationId),
                  let image = UIImage(data: data) else { return nil }
            return (data, image)
        }.value

        guard let loaded else { return }
        selectedImage = loaded.1
        // The bytes go into the draft too: saving without touching the photo must not
        // look like a deletion to DatabaseService.updateMedication.
        draft.medicationImageData = loaded.0
    }
    
    func requestImageSelection(source: MediaSource) {
        Task {
            do {
                let image = try await mediaPickerService.pickImage(source: source)
                
                // Compress off the main actor so the UI thread isn't blocked
                let compressedData = await Task.detached(priority: .userInitiated) {
                    return image.jpegData(compressionQuality: 0.7)
                }.value

                self.selectedImage = image
                self.draft.medicationImageData = compressedData
            } catch {
                AppLog.media.error("Photo selection failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    func removeImage() {
        selectedImage = nil
        draft.medicationImageData = nil
    }
}
