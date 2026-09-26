//
//  DiaryCheckInViewModel.swift
//  Plekio
//
//  Created by Edward Gasparian on 24.08.2026.
//

import Combine
import OSLog
import SwiftUI

@MainActor
final class DiaryCheckInViewModel: DiaryCheckInViewModelProtocol {

    // MARK: - Properties

    @Published var draft = DiaryEntryDraft()
    @Published var selectedImages: [UIImage] = []
    @Published var showingPhotoSourceMenu = false

    /// Set only through `startEditing(_:)`.
    private var editingEntry: DiaryEntrySnapshot?

    private let diary: any DiaryRepository
    private let photos: any PhotoStoring
    private let errors: any ErrorReporting
    private let time: any TimeSource

    // MARK: - Init

    init(diary: any DiaryRepository, photos: any PhotoStoring, errors: any ErrorReporting, time: any TimeSource = SystemTime()) {
        self.diary = diary
        self.photos = photos
        self.errors = errors
        self.time = time
    }

    /// Over the SwiftData store — the shape tests use.
    convenience init(
        dbService: any DiaryStoring & BloodPressureStoring,
        photos: any PhotoStoring,
        errors: any ErrorReporting,
        time: any TimeSource = SystemTime()
    ) {
        self.init(
            diary: SwiftDataDiaryRepository(store: dbService),
            photos: photos,
            errors: errors,
            time: time
        )
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

    func attachPhoto(_ image: UIImage) async {
        // Compressed off the main actor. pngData covers images with no CGImage,
        // for which jpegData returns nil.
        let compressedData = await Task.detached(priority: .userInitiated) {
            image.jpegData(compressionQuality: 0.6) ?? image.pngData()
        }.value

        guard let compressedData else {
            AppLog.media.error("Picked image could not be encoded; diary photo not attached")
            return
        }
        selectedImages.append(image)
        draft.photos.append(compressedData)
        draft.photosModified = true
    }

    func removePhoto(at index: Int) {
        guard selectedImages.indices.contains(index), draft.photos.indices.contains(index) else { return }
        selectedImages.remove(at: index)
        draft.photos.remove(at: index)
        draft.photosModified = true
    }

    // MARK: - Editing

    func startEditing(_ entry: DiaryEntrySnapshot) async {
        // `.task` can run again; a second load would wipe edits already typed.
        guard editingEntry == nil else { return }
        editingEntry = entry

        draft = DiaryEntryDraft(from: entry)
        await loadPhotos(for: entry)
    }

    private func loadPhotos(for entry: DiaryEntrySnapshot) async {
        let ids = entry.photoIds
        guard !ids.isEmpty else { return }

        // Read and decode off the main actor; compactMap keeps photo order.
        let loaded = await Task.detached(priority: .userInitiated) { () -> [(Data, UIImage)] in
            ids.compactMap { id in
                guard let data = self.photos.loadDataFromDisk(for: id),
                      let image = UIImage(data: data) else { return nil }
                return (data, image)
            }
        }.value

        draft.photos = loaded.map(\.0)
        selectedImages = loaded.map(\.1)
        // photosModified stays false: preloading is not an edit, and setting it
        // would make every save rewrite all photo files under new UUIDs.
    }

    // MARK: - Save

    /// Returns `false` when the save failed, so the view stays open and input isn't lost.
    @discardableResult
    func save() -> Bool {
        // The pickers stop at now; this guards every other way a draft could get here.
        guard draft.checkInDate <= time.now else {
            errors.report(DiaryEntryError.inFuture)
            return false
        }
        return errors.run { [self] in
            if let editingEntry {
                try diary.updateEntry(id: editingEntry.id, with: draft)
            } else {
                try diary.saveEntry(draft)
            }
        }
    }
}

// MARK: - DiaryEntryError

enum DiaryEntryError: LocalizedError {
    case inFuture

    var errorDescription: String? {
        String(localized: "A diary entry can't be dated in the future.")
    }
}

// MARK: - Mock

#if DEBUG
final class MockDiaryCheckInViewModel: DiaryCheckInViewModelProtocol {
    @Published var draft = DiaryEntryDraft()
    @Published var selectedImages: [UIImage] = []
    @Published var showingPhotoSourceMenu = false

    init() {}

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

    func attachPhoto(_ image: UIImage) async {}
    func removePhoto(at index: Int) {}
    func startEditing(_ entry: DiaryEntrySnapshot) async { draft = DiaryEntryDraft(from: entry) }
    @discardableResult
    func save() -> Bool { true }
}
#endif
