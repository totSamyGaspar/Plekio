//
//  DiaryCheckInViewModel.swift
//  PillFlow
//
//  Created by Edward Gasparian on 24.08.2026.
//

import Combine
import OSLog
import SwiftUI

@MainActor
final class DiaryCheckInViewModel: DiaryCheckInViewModelProtocol {
    @Published var draft = DiaryEntryDraft()
    @Published var selectedImages: [UIImage] = []
    @Published var showingPhotoSourceMenu = false

    /// Set only through `startEditing(_:)`. Kept private because the view used
    /// to assign it directly, bypassing the protocol.
    private var editingEntry: DiaryEntry?

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
                AppLog.media.error("Diary photo selection failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func removePhoto(at index: Int) {
        guard selectedImages.indices.contains(index), draft.photos.indices.contains(index) else { return }
        selectedImages.remove(at: index)
        draft.photos.remove(at: index)
        draft.photosModified = true
    }

    // MARK: - Editing

    func startEditing(_ entry: DiaryEntry) async {
        // `.task` can run again (returning to the screen, a scene change), and a
        // second load would wipe edits the user has already typed.
        guard editingEntry == nil else { return }
        editingEntry = entry

        draft = DiaryEntryDraft(from: entry)
        await loadPhotos(for: entry)
    }

    /// Loads the entry's photos from disk. This used to run synchronously in the
    /// view's `init` — on the main thread, and again on every re-creation of the
    /// view struct.
    private func loadPhotos(for entry: DiaryEntry) async {
        let ids = entry.photoIds
        guard !ids.isEmpty else { return }

        // Read and decode off the main actor, same approach as
        // AddMedicationViewModel.requestImageSelection. compactMap walks the
        // original id array, so photo order is preserved.
        let loaded = await Task.detached(priority: .userInitiated) { () -> [(Data, UIImage)] in
            ids.compactMap { id in
                guard let data = ImageCache.shared.loadDataFromDisk(for: id),
                      let image = UIImage(data: data) else { return nil }
                return (data, image)
            }
        }.value

        draft.photos = loaded.map(\.0)
        selectedImages = loaded.map(\.1)
        // photosModified deliberately stays false: preloading is not an edit.
        // Otherwise DatabaseService.updateDiaryEntry would delete and rewrite every
        // photo file under fresh UUIDs on every save.
    }

    // MARK: - Save

    /// Returns `false` when the save failed, so the view stays open and the
    /// user's input isn't lost.
    @discardableResult
    func save() -> Bool {
        AppErrorPresenter.shared.run { [self] in
            if let editingEntry {
                try dbService.updateDiaryEntry(editingEntry, with: draft)
            } else {
                try dbService.saveDiaryEntry(draft: draft)
            }
        }
    }
}

// MARK: - Mock (previews)

#if DEBUG
final class MockDiaryCheckInViewModel: DiaryCheckInViewModelProtocol {
    @Published var draft = DiaryEntryDraft()
    @Published var selectedImages: [UIImage] = []
    @Published var showingPhotoSourceMenu = false

    init() {}

    // Routed through shared helpers below. The mock used to reimplement this
    // logic and had already drifted from the real view model: it neither
    // trimmed whitespace nor rejected duplicates.
    func toggleSymptom(_ symptom: String) { Self.toggle(symptom, in: &draft.symptoms) }
    func addCustomSymptom(_ symptom: String) { Self.addCustom(symptom, to: &draft.symptoms) }
    func toggleMilestone(_ tag: String) { Self.toggle(tag, in: &draft.milestoneTags) }
    func addCustomMilestone(_ tag: String) { Self.addCustom(tag, to: &draft.milestoneTags) }

    private static func toggle(_ value: String, in list: inout [String]) {
        if let index = list.firstIndex(of: value) {
            list.remove(at: index)
        } else {
            list.append(value)
        }
    }

    private static func addCustom(_ value: String, to list: inout [String]) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !list.contains(trimmed) else { return }
        list.append(trimmed)
    }

    func requestImageSelection(source: MediaSource) {}
    func removePhoto(at index: Int) {}
    func startEditing(_ entry: DiaryEntry) async { draft = DiaryEntryDraft(from: entry) }
    @discardableResult
    func save() -> Bool { true }
}
#endif
