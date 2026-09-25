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
        // Files first: if they can't be written, nothing is saved.
        let newPhotos = draft.photos.map { (UUID(), $0) }
        try persistence.writePhotosOrThrow(newPhotos)

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
        entry.photoIds = newPhotos.map(\.0)

        context.insert(entry)
        do {
            try persistence.commit([.diary])
        } catch {
            deletePhotos(newPhotos.map(\.0))
            throw error
        }
    }

    /// Order matters: new files → commit → delete old files. A failure at any step
    /// leaves the previous photos intact.
    func updateDiaryEntry(_ entry: DiaryEntry, with draft: DiaryEntryDraft) throws {
        // Replaced only if the user touched photos; the editor always preloads them.
        var plan = PhotoPlan(ids: entry.photoIds, newFiles: [], removed: [])
        if draft.photosModified {
            plan = photoPlan(old: entry.photoIds, drafted: draft.photos)
            try persistence.writePhotosOrThrow(plan.newFiles)
        }

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
        entry.photoIds = plan.ids

        do {
            try persistence.commit([.diary])
        } catch {
            deletePhotos(plan.newFiles.map(\.0))
            throw error
        }

        deletePhotos(plan.removed)
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

    /// Photo files go only after the commit: a failed delete leaves everything in place.
    func deleteAllDiaryEntries() throws {
        let entries = fetchAllDiaryEntries()
        guard !entries.isEmpty else { return }

        let photoIds = entries.flatMap(\.photoIds)
        for entry in entries {
            context.delete(entry)
        }
        try persistence.commit([.diary])

        deletePhotos(photoIds)
    }

    // MARK: - Photo Plan

    private struct PhotoPlan {
        /// The entry's photo ids after the save, in the draft's order.
        let ids: [UUID]
        /// Files to write before committing.
        let newFiles: [(UUID, Data)]
        /// Old files no longer referenced; deleted only after the commit.
        let removed: [UUID]
    }

    /// Keeps unchanged photos under their ids (matched by bytes: the editor
    /// preloads them from disk), gives new ones fresh ids.
    private func photoPlan(old: [UUID], drafted: [Data]) -> PhotoPlan {
        var available = old.compactMap { id in photos.loadDataFromDisk(for: id).map { (id, $0) } }
        var ids: [UUID] = []
        var newFiles: [(UUID, Data)] = []

        for data in drafted {
            if let index = available.firstIndex(where: { $0.1 == data }) {
                ids.append(available.remove(at: index).0)
            } else {
                let id = UUID()
                ids.append(id)
                newFiles.append((id, data))
            }
        }

        let kept = Set(ids)
        return PhotoPlan(ids: ids, newFiles: newFiles, removed: old.filter { !kept.contains($0) })
    }

    private func deletePhotos(_ ids: [UUID]) {
        for id in ids {
            photos.deleteFromDisk(for: id)
        }
    }
}
