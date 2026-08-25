//
//  DiaryCheckInViewModel.swift
//  PillFlow
//
//  Created by Edward Gasparian on 24.08.2026.
//

import SwiftUI
import Combine

@MainActor
final class DiaryCheckInViewModel: DiaryCheckInViewModelProtocol {
    @Published var draft = DiaryEntryDraft()
    @Published var selectedImages: [UIImage] = []
    @Published var showingPhotoSourceMenu = false

    /// Set (outside the protocol) by DiaryCheckInView.init(editingEntry:) when
    /// this form is editing an existing entry rather than creating a new one —
    /// mirrors AddMedicationView's isEditing pattern.
    var editingEntry: DiaryEntry?

    private let dbService: DatabaseServiceProtocol
    private let mediaPickerService: MediaPickerServiceProtocol

    init(dbService: DatabaseServiceProtocol, mediaPickerService: MediaPickerServiceProtocol) {
        self.dbService = dbService
        self.mediaPickerService = mediaPickerService
    }

    // MARK: - Tags

    func toggleSymptom(_ symptom: String) {
        toggle(symptom, in: &draft.symptoms)
    }

    func addCustomSymptom(_ symptom: String) {
        addCustom(symptom, to: &draft.symptoms)
    }

    func toggleMilestone(_ tag: String) {
        toggle(tag, in: &draft.milestoneTags)
    }

    func addCustomMilestone(_ tag: String) {
        addCustom(tag, to: &draft.milestoneTags)
    }

    private func toggle(_ value: String, in list: inout [String]) {
        if let index = list.firstIndex(of: value) {
            list.remove(at: index)
        } else {
            list.append(value)
        }
    }

    private func addCustom(_ value: String, to list: inout [String]) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !list.contains(trimmed) else { return }
        list.append(trimmed)
    }

    // MARK: - Photos

    func requestImageSelection(source: MediaSource) {
        Task {
            do {
                let image = try await mediaPickerService.pickImage(source: source)

                // Compress off the main actor, same approach as AddMedicationViewModel.
                let compressedData = await Task.detached(priority: .userInitiated) {
                    image.jpegData(compressionQuality: 0.6)
                }.value

                guard let compressedData else { return }
                selectedImages.append(image)
                draft.photos.append(compressedData)
                draft.photosModified = true
            } catch {
                print("🚨 Diary photo selection error: \(error)")
            }
        }
    }

    func removePhoto(at index: Int) {
        guard selectedImages.indices.contains(index), draft.photos.indices.contains(index) else { return }
        selectedImages.remove(at: index)
        draft.photos.remove(at: index)
        draft.photosModified = true
    }

    // MARK: - Save

    func save() {
        if let editingEntry {
            dbService.updateDiaryEntry(editingEntry, with: draft)
        } else {
            dbService.saveDiaryEntry(draft: draft)
        }
    }
}

// MARK: - Mock (previews)

final class MockDiaryCheckInViewModel: DiaryCheckInViewModelProtocol {
    @Published var draft = DiaryEntryDraft()
    @Published var selectedImages: [UIImage] = []
    @Published var showingPhotoSourceMenu = false

    init() {}

    func toggleSymptom(_ symptom: String) {
        if let index = draft.symptoms.firstIndex(of: symptom) {
            draft.symptoms.remove(at: index)
        } else {
            draft.symptoms.append(symptom)
        }
    }

    func addCustomSymptom(_ symptom: String) {
        draft.symptoms.append(symptom)
    }

    func toggleMilestone(_ tag: String) {
        if let index = draft.milestoneTags.firstIndex(of: tag) {
            draft.milestoneTags.remove(at: index)
        } else {
            draft.milestoneTags.append(tag)
        }
    }

    func addCustomMilestone(_ tag: String) {
        draft.milestoneTags.append(tag)
    }

    func requestImageSelection(source: MediaSource) {}
    func removePhoto(at index: Int) {}
    func save() {}
}
