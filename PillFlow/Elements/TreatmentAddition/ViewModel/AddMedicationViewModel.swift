//
//  AddMedicationViewModel.swift
//  PillFlow
//
//  Created by Edward Gasparian on 20.05.2026.
//

import SwiftUI
import Combine

@MainActor
final class AddMedicationViewModel: AddMedicationViewModelProtocol {
    @Published var draft = MedicationDraft()
    @Published var selectedImage: UIImage?
    @Published var showingPhotoSourceMenu = false
    
    private let mediaPickerService: MediaPickerServiceProtocol
    
    init(mediaPickerService: MediaPickerServiceProtocol) {
        self.mediaPickerService = mediaPickerService
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
                print("Photo selection error: \(error)")
            }
        }
    }
    
    func removeImage() {
        selectedImage = nil
        draft.medicationImageData = nil
    }
}
