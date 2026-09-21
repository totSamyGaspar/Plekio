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
        
        // Read here rather than in the view's init, where it would be a synchronous
        // disk read on the main thread, repeated on every re-creation of the struct.
        let medicationId = medication.id
        let loaded = await Task.detached(priority: .userInitiated) { () -> (Data, UIImage)? in
            guard let data = ImageCache.shared.loadDataFromDisk(for: medicationId),
                  let image = UIImage(data: data) else { return nil }
            return (data, image)
        }.value
        
        guard let loaded else { return }
        selectedImage = loaded.1
        // The bytes go into the draft too, so the form has them if the user replaces
        // the photo. `photoModified` stays false — see MedicationDraft.
        draft.medicationImageData = loaded.0
    }
    
    func requestImageSelection(source: MediaSource) {
        Task {
            do {
                let image = try await mediaPickerService.pickImage(source: source)
                
                // Compress off the main actor so the UI thread isn't blocked.
                // pngData is the fallback: jpegData returns nil for an image with no
                // CGImage behind it, and the preview then showed a photo that was
                // never written to disk — a placeholder everywhere else in the app.
                let compressedData = await Task.detached(priority: .userInitiated) {
                    return image.jpegData(compressionQuality: 0.7) ?? image.pngData()
                }.value
                
                guard let compressedData else {
                    AppLog.media.error("Picked image could not be encoded; photo not attached")
                    return
                }
                
                self.selectedImage = image
                self.draft.medicationImageData = compressedData
                self.draft.photoModified = true
            } catch {
                AppLog.media.error("Photo selection failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    func removeImage() {
        selectedImage = nil
        draft.medicationImageData = nil
        draft.photoModified = true
    }
}
