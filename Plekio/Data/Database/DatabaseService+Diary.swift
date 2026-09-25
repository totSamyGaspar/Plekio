//
//  DatabaseService+Diary.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.09.2026.
//

import Foundation
import OSLog
import SwiftData

extension DatabaseService: DiaryStoring {

    // MARK: - DiaryStoring

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

        // Ids generated up front; files written only after commit.
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

        // Replaced only if the user touched photos; the editor always preloads them.
        var removedPhotoIds: [UUID] = []
        var pendingPhotos: [(UUID, Data)] = []

        if draft.photosModified {
            removedPhotoIds = entry.photoIds
            pendingPhotos = draft.photos.map { (UUID(), $0) }
            entry.photoIds = pendingPhotos.map(\.0)
        }

        try persistence.commit([.diary])

        for id in removedPhotoIds {
            photos.deleteFromDisk(for: id)
        }
        persistence.persistPhotos(pendingPhotos)
    }

    func fetchAllDiaryEntries() -> [DiaryEntry] {
        let descriptor = FetchDescriptor<DiaryEntry>(sortBy: [SortDescriptor(\.checkInDate, order: .reverse)])
        return fetch(descriptor)
    }

    func deleteDiaryEntry(_ entry: DiaryEntry) throws {
        let photoIds = entry.photoIds

        context.delete(entry)
        try persistence.commit([.diary])

        for photoId in photoIds {
            photos.deleteFromDisk(for: photoId)
        }
    }
}
