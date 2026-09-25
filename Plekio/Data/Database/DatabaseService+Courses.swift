//
//  DatabaseService+Courses.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.09.2026.
//

import Foundation
import OSLog
import SwiftData

extension DatabaseService: CourseStoring {

    // MARK: - Save

    func saveCourse(
        name: String,
        startDate: Date,
        endDate: Date,
        drafts: [MedicationDraft]
    ) throws {
        let course = TreatmentCourse(
            name: name,
            startDate: startDate,
            endDate: endDate
        )
        context.insert(course)

        // Photos are written only after commit, so a rollback leaves no orphan files.
        var pendingPhotos: [(UUID, Data)] = []

        for draft in drafts {
            let med = MedicationItem(
                id: draft.id,
                name: draft.name,
                formSystemImage: draft.formSystemImage,
                dosage: draft.dosage,
                timesOfDay: draft.timesOfDay,
                frequencyDays: draft.frequencyDays,
                stockCount: draft.stockCount,
                lowStockThreshold: draft.lowStockThreshold
            )
            course.medications.append(med)
            if let imageData = draft.medicationImageData {
                pendingPhotos.append((med.id, imageData))
            }
        }

        try persistence.commit([.courses])

        persistence.persistPhotos(pendingPhotos)
    }

    /// Copies the course with new medication ids, so the original's dose logs stay
    /// intact; photos (keyed by medication id) are copied to the new ids.
    func duplicateCourse(_ course: TreatmentCourse, startDate: Date, endDate: Date) throws {
        let newCourse = TreatmentCourse(
            name: course.name,
            startDate: startDate,
            endDate: endDate,
            // The chain's first course, so a copy of a copy is still the same treatment.
            repeatedFromId: course.repeatLineageId
        )
        context.insert(newCourse)

        // Files written only after commit.
        var pendingPhotos: [(UUID, Data)] = []

        for source in course.medications {
            let copyId = UUID()
            let med = MedicationItem(
                id: copyId,
                name: source.name,
                formSystemImage: source.formSystemImage,
                dosage: source.dosage,
                timesOfDay: source.timesOfDay,
                frequencyDays: source.frequencyDays,
                stockCount: source.stockCount,
                lowStockThreshold: source.lowStockThreshold
            )
            newCourse.medications.append(med)

            if let imageData = photos.loadDataFromDisk(for: source.id) {
                pendingPhotos.append((copyId, imageData))
            }
        }

        try persistence.commit([.courses])

        persistence.persistPhotos(pendingPhotos)
    }

    // MARK: - Refill

    func refillStock(for medication: MedicationItem, amount: Int) throws {
        medication.stockCount += amount
        try persistence.commit([.courses])
    }

    // MARK: - Update Medication

    func updateMedication(_ medication: MedicationItem, with draft: MedicationDraft) throws {
        // Captured first: logs are keyed by hour+minute and must be remapped.
        let previousTimes = medication.timesOfDay

        medication.name = draft.name
        medication.formSystemImage = draft.formSystemImage
        medication.dosage = draft.dosage
        medication.stockCount = draft.stockCount
        medication.lowStockThreshold = draft.lowStockThreshold
        medication.frequencyDays = draft.frequencyDays
        medication.timesOfDay = draft.timesOfDay

        remapLogs(of: medication, from: previousTimes, to: draft.timesOfDay)

        // Touch disk only after commit and only if the photo was modified: an
        // untouched draft may be empty just because the preload hasn't finished.
        let photoModified = draft.photoModified
        let newImageData = draft.medicationImageData
        let medicationId = medication.id

        try persistence.commit([.courses])

        guard photoModified else { return }

        if let newImageData {
            persistence.persistPhotos([(medicationId, newImageData)])
        } else {
            photos.deleteFromDisk(for: medicationId)
        }
    }

    /// Moves dose logs onto the new times by position, since logs are matched by
    /// hour+minute; logs of removed slots stay as history.
    private func remapLogs(of medication: MedicationItem, from oldTimes: [Date], to newTimes: [Date]) {
        let calendar = time.calendar

        // Minutes from midnight: an Int, since arrays of tuples have no `!=`.
        func slot(_ date: Date) -> Int {
            calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        }

        let oldSlots = oldTimes.map(slot)
        let newSlots = newTimes.map(slot)
        guard oldSlots != newSlots else { return }

        // Collected first: mutating in place could swap two slots.
        var moves: [(log: DoseLog, newDate: Date)] = []

        for (index, oldSlot) in oldSlots.enumerated() {
            guard index < newSlots.count else { break }
            let newSlot = newSlots[index]
            guard oldSlot != newSlot else { continue }

            for log in medication.logs where slot(log.scheduledTime) == oldSlot {
                if let moved = calendar.date(
                    bySettingHour: newSlot / 60,
                    minute: newSlot % 60,
                    second: 0,
                    of: log.scheduledTime
                ) {
                    moves.append((log, moved))
                }
            }
        }

        for move in moves {
            move.log.scheduledTime = move.newDate
        }
    }

    // MARK: - Course Management

    func fetchCourse(id: UUID) -> TreatmentCourse? {
        let descriptor = FetchDescriptor<TreatmentCourse>(predicate: #Predicate { $0.id == id })
        return fetch(descriptor).first
    }

    func fetchAllCourses() -> [TreatmentCourse] {
        let descriptor = FetchDescriptor<TreatmentCourse>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        return fetch(descriptor)
    }

    func deleteCourse(_ course: TreatmentCourse) throws {
        // Cascade does not remove photo files; erase them only after commit.
        let photoIds = course.medications.map(\.id)

        context.delete(course)
        try persistence.commit([.courses])

        for id in photoIds {
            photos.deleteFromDisk(for: id)
        }
    }

    func deleteMedication(_ medication: MedicationItem) throws {
        let photoId = medication.id
        context.delete(medication)
        try persistence.commit([.courses])

        // After commit, so a rollback can't leave the medication without its photo.
        photos.deleteFromDisk(for: photoId)
    }

    func updateCourseDetails(course: TreatmentCourse, name: String, startDate: Date, endDate: Date) throws {
        course.name = name
        course.startDate = startDate
        course.endDate = endDate
        try persistence.commit([.courses])
    }

    func addMedication(draft: MedicationDraft, to course: TreatmentCourse) throws {
        let med = MedicationItem(
            id: draft.id,
            name: draft.name,
            formSystemImage: draft.formSystemImage,
            dosage: draft.dosage,
            timesOfDay: draft.timesOfDay,
            frequencyDays: draft.frequencyDays,
            stockCount: draft.stockCount,
            lowStockThreshold: draft.lowStockThreshold
        )
        course.medications.append(med)

        try persistence.commit([.courses])

        if let imageData = draft.medicationImageData {
            persistence.persistPhotos([(med.id, imageData)])
        }
    }
}
