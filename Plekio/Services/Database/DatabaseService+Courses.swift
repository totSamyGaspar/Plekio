//
//  DatabaseService+Courses.swift
//  Plekio
//

import Foundation
import OSLog
import SwiftData

/// Courses and the medications inside them.
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

        // Collected here and written only after a successful commit: a rollback
        // must not leave files on disk for medications that no longer exist.
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

    /// Starts a finished course over: a brand-new course with fresh dates and a
    /// fresh copy of every medication.
    ///
    /// The medications get new ids rather than being moved, so the original stays
    /// in the history with its own dose logs intact — repeating a course must not
    /// rewrite what actually happened last time. Photos live on disk keyed by the
    /// medication id (see ImageCache), so each one is copied across to the new id.
    func duplicateCourse(_ course: TreatmentCourse, startDate: Date, endDate: Date) throws {
        let newCourse = TreatmentCourse(
            name: course.name,
            startDate: startDate,
            endDate: endDate,
            // The chain's first course, so repeating a copy of a copy is still
            // recognised as the same treatment running again.
            repeatedFromId: course.repeatLineageId
        )
        context.insert(newCourse)

        // Same reason as in saveCourse: files are written only once the write
        // has actually committed.
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

    // MARK: - Update meds

    func updateMedication(_ medication: MedicationItem, with draft: MedicationDraft) throws {
        // Captured before assigning: dose logs are keyed by hour+minute, so they
        // have to be remapped once the times move.
        let previousTimes = medication.timesOfDay

        medication.name = draft.name
        medication.formSystemImage = draft.formSystemImage
        medication.dosage = draft.dosage
        medication.stockCount = draft.stockCount
        medication.lowStockThreshold = draft.lowStockThreshold
        medication.frequencyDays = draft.frequencyDays
        medication.timesOfDay = draft.timesOfDay

        remapLogs(of: medication, from: previousTimes, to: draft.timesOfDay)

        // Disk is touched only when the user actually changed the photo, and only
        // after a successful commit — a rollback must not leave the record without
        // its file. An untouched draft is left alone: it can be empty simply because
        // the preload hasn't finished, and treating that as a deletion erased photos
        // on an unrelated edit (a rename). Same contract as updateDiaryEntry.
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

    /// Moves existing dose logs onto the new times by position — the first dose of
    /// the day stays the first.
    ///
    /// `DoseLog` is looked up by hour+minute (see `DoseSchedule.slotKey`), so without
    /// this a dose moved from 8:00 to 9:00 orphans its logs: the day reads as
    /// unlogged even though stock was already deducted.
    ///
    /// Logs of removed slots stay in the store as history. Statistics are computed
    /// from the schedule, so they no longer affect any number.
    private func remapLogs(of medication: MedicationItem, from oldTimes: [Date], to newTimes: [Date]) {
        let calendar = Calendar.current

        /// A dose slot as minutes from midnight. An `(hour, minute)` tuple can't be
        /// used here: tuples can't conform to Equatable, so arrays of them have no
        /// `!=`. A single integer compares at any level.
        func slot(_ date: Date) -> Int {
            calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        }

        let oldSlots = oldTimes.map(slot)
        let newSlots = newTimes.map(slot)
        guard oldSlots != newSlots else { return }

        // Collected first and applied after: if one slot's new time equals another
        // slot's old time, mutating in place would swap the two.
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

    /// Looks a course up by id: NavigationPath stores the UUID, not the @Model
    /// object itself.
    func fetchCourse(id: UUID) -> TreatmentCourse? {
        let descriptor = FetchDescriptor<TreatmentCourse>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    func fetchAllCourses() -> [TreatmentCourse] {
        let descriptor = FetchDescriptor<TreatmentCourse>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func deleteCourse(_ course: TreatmentCourse) throws {
        // Deleting the course cascades to its MedicationItem records, but photo files
        // on disk are not removed automatically. Ids are captured before the delete and
        // the files erased after a successful commit, so a rollback can't leave a course
        // without its photos.
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

        // After the record is gone, so a rollback can't leave the medication in the
        // store without its photo.
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
