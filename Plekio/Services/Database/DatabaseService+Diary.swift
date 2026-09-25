//
//  DatabaseService+Diary.swift
//  Plekio
//

import Foundation
import OSLog
import SwiftData

/// Diary check-ins.
extension DatabaseService: DiaryStoring {

    // MARK: - Diary

    func saveDiaryEntry(draft: DiaryEntryDraft) throws {
        let entry = DiaryEntry(
            id: draft.id,
            checkInDate: draft.checkInDate,
            moodLabel: draft.mood.rawValue,
            moodScore: draft.mood.score,
            physicalSummary: draft.physicalSummary,
            energyLevel: draft.energyLevel,
            discomfortLevel: draft.discomfortLevel,
            sleepHours: draft.sleepHours,
            sleepQuality: draft.sleepQuality.rawValue,
            waterGlasses: draft.waterGlasses,
            symptoms: draft.symptoms,
            reflectionNotes: draft.reflectionNotes,
            milestoneTags: draft.milestoneTags,
            isQuickLog: draft.isQuickLog
        )

        // Ids are generated up front, files written only after commit — same approach
        // as MedicationItem's photo, see ImageCache.swift.
        let pendingPhotos = draft.photos.map { (UUID(), $0) }
        entry.photoIds = pendingPhotos.map(\.0)

        context.insert(entry)
        try persistence.commit([.diary])

        persistence.persistPhotos(pendingPhotos)
    }

    func updateDiaryEntry(_ entry: DiaryEntry, with draft: DiaryEntryDraft) throws {
        entry.checkInDate = draft.checkInDate
        entry.moodLabel = draft.mood.rawValue
        entry.moodScore = draft.mood.score
        entry.physicalSummary = draft.physicalSummary
        entry.energyLevel = draft.energyLevel
        entry.discomfortLevel = draft.discomfortLevel
        entry.sleepHours = draft.sleepHours
        entry.sleepQuality = draft.sleepQuality.rawValue
        entry.waterGlasses = draft.waterGlasses
        entry.symptoms = draft.symptoms
        entry.reflectionNotes = draft.reflectionNotes
        entry.milestoneTags = draft.milestoneTags
        entry.isQuickLog = draft.isQuickLog

        // Replaced wholesale, but only when the user actually touched photos.
        // DiaryCheckInView.init(editingEntry:) always preloads existing photos into the
        // draft, so without this guard saving a mood change alone deleted every file and
        // rewrote byte-identical copies under fresh UUIDs.
        var removedPhotoIds: [UUID] = []
        var pendingPhotos: [(UUID, Data)] = []

        if draft.photosModified {
            removedPhotoIds = entry.photoIds
            pendingPhotos = draft.photos.map { (UUID(), $0) }
            entry.photoIds = pendingPhotos.map(\.0)
        }

        try persistence.commit([.diary])

        // Disk is synced only after the write succeeds.
        for id in removedPhotoIds {
            photos.deleteFromDisk(for: id)
        }
        persistence.persistPhotos(pendingPhotos)
    }

    func fetchAllDiaryEntries() -> [DiaryEntry] {
        let descriptor = FetchDescriptor<DiaryEntry>(sortBy: [SortDescriptor(\.checkInDate, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func deleteDiaryEntry(_ entry: DiaryEntry) throws {
        let photoIds = entry.photoIds

        context.delete(entry)
        try persistence.commit([.diary])

        // Clean up photo files on disk — they aren't removed automatically.
        for photoId in photoIds {
            photos.deleteFromDisk(for: photoId)
        }
    }
}
