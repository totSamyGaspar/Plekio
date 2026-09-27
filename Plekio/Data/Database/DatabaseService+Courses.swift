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
        // Captured first: the old schedule is kept for past days, and today's logs remapped.
        let previousTimes = medication.timesOfDay
        let previousFrequency = medication.frequencyDays
        let previousDosage = medication.dosage

        medication.name = draft.name
        medication.formSystemImage = draft.formSystemImage
        medication.dosage = draft.dosage
        medication.stockCount = draft.stockCount
        medication.lowStockThreshold = draft.lowStockThreshold
        medication.frequencyDays = draft.frequencyDays
        medication.timesOfDay = draft.timesOfDay

        recordRevision(of: medication, times: previousTimes, frequencyDays: previousFrequency, dosage: previousDosage)
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

    /// Keeps the schedule that applied before today, so past days, statistics and
    /// the report aren't recomputed on the new one. Nothing to keep if the course
    /// hasn't started or the schedule didn't change.
    private func recordRevision(
        of medication: MedicationItem,
        times oldTimes: [Date],
        frequencyDays oldFrequency: Int,
        dosage oldDosage: Int
    ) {
        let calendar = time.calendar
        let today = calendar.startOfDay(for: time.now)

        func minutes(_ times: [Date]) -> [Int] {
            times.map { calendar.component(.hour, from: $0) * 60 + calendar.component(.minute, from: $0) }
        }
        guard minutes(oldTimes) != minutes(medication.timesOfDay)
                || oldFrequency != medication.frequencyDays
                || oldDosage != medication.dosage else { return }

        guard let course = medication.course else { return }
        let earliestStart = course.dateRevisions.reduce(course.startDate) { min($0, $1.startDate) }
        guard calendar.startOfDay(for: earliestStart) < today else { return }
        // Edited again today: the revision already holds what applied before today.
        guard !medication.scheduleRevisions.contains(where: { $0.validUntil == today }) else { return }

        let revision = ScheduleRevision(
            validUntil: today, timesOfDay: oldTimes, frequencyDays: oldFrequency, dosage: oldDosage
        )
        revision.medication = medication
        medication.scheduleRevisions.append(revision)
    }

    /// Moves today's and later logs onto the new times by position; past logs keep
    /// their times (the old schedule still applies to past days).
    private func remapLogs(of medication: MedicationItem, from oldTimes: [Date], to newTimes: [Date]) {
        let calendar = time.calendar
        let today = calendar.startOfDay(for: time.now)

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

            for log in medication.logs where log.scheduledTime >= today && slot(log.scheduledTime) == oldSlot {
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
        let calendar = time.calendar
        let today = calendar.startOfDay(for: time.now)
        let datesChanged = !calendar.isDate(course.startDate, inSameDayAs: startDate)
            || !calendar.isDate(course.endDate, inSameDayAs: endDate)
        // Preserve even an empty past (e.g. a future course moved into the past).
        // Repeated edits today must keep the dates that applied before the first edit.
        if datesChanged, !course.dateRevisions.contains(where: { $0.validUntil == today }) {
            let revision = CourseDateRevision(
                validUntil: today, startDate: course.startDate, endDate: course.endDate
            )
            course.dateRevisions.append(revision)
        }
        course.name = name
        course.startDate = startDate
        course.endDate = endDate
        try persistence.commit([.courses])
    }

    /// Added to a running course, it starts today: earlier days weren't its to miss.
    func addMedication(draft: MedicationDraft, to course: TreatmentCourse) throws {
        let calendar = time.calendar
        let today = calendar.startOfDay(for: time.now)
        let earliestStart = course.dateRevisions.reduce(course.startDate) { min($0, $1.startDate) }
        let courseStarted = calendar.startOfDay(for: earliestStart) < today

        let med = MedicationItem(
            id: draft.id,
            name: draft.name,
            formSystemImage: draft.formSystemImage,
            dosage: draft.dosage,
            timesOfDay: draft.timesOfDay,
            frequencyDays: draft.frequencyDays,
            stockCount: draft.stockCount,
            lowStockThreshold: draft.lowStockThreshold,
            startDate: courseStarted ? today : nil
        )
        course.medications.append(med)

        try persistence.commit([.courses])

        if let imageData = draft.medicationImageData {
            persistence.persistPhotos([(med.id, imageData)])
        }
    }
}
