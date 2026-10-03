//
//  DatabaseService+Erasing.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.10.2026.
//

import Foundation
import SwiftData

// MARK: - DataErasingStore

/// Bulk deletions behind Settings → Manage your data.
@MainActor
protocol DataErasingStore: AnyObject {
    func storedDataSummary() -> StoredDataSummary
    /// Diary entries, their photos and blood-pressure readings.
    func deleteDiary() throws
    /// Courses that have ended, with their doses and photos; running ones stay.
    func deleteFinishedCourses() throws
    /// Every course and diary record.
    func deleteAllRecords() throws
}

/// What there is to delete, so the screen can disable empty actions.
nonisolated struct StoredDataSummary: Equatable, Sendable {
    var diaryRecords = 0
    var finishedCourses = 0
    var courses = 0

    var isEmpty: Bool { diaryRecords == 0 && courses == 0 }
}

// MARK: - DatabaseService

/// Conformance comes through DatabaseServiceProtocol.
extension DatabaseService {

    func storedDataSummary() -> StoredDataSummary {
        let courses = fetchAllCourses()
        return StoredDataSummary(
            diaryRecords: fetchAllDiaryEntries().count + fetchAllBloodPressureReadings().count,
            finishedCourses: finishedCourses(in: courses).count,
            courses: courses.count
        )
    }

    func deleteDiary() throws {
        try delete(courses: [], diary: true)
    }

    func deleteFinishedCourses() throws {
        try delete(courses: finishedCourses(in: fetchAllCourses()), diary: false)
    }

    func deleteAllRecords() throws {
        try delete(courses: fetchAllCourses(), diary: true)
    }

    // MARK: - Helpers

    private func finishedCourses(in courses: [TreatmentCourse]) -> [TreatmentCourse] {
        courses.filter { !$0.isActive(on: time.now, calendar: time.calendar) }
    }

    /// One commit for everything, deleted one by one (a batch delete bypasses the
    /// context, so `commit` couldn't roll it back). Photo files go only after the
    /// commit: a failed delete leaves everything in place.
    private func delete(courses: [TreatmentCourse], diary: Bool) throws {
        var changes: Set<DatabaseChange> = []
        // Medication photos are keyed by medication id; doses go with the course.
        var photoIds = courses.flatMap { $0.medications.map(\.id) }
        for course in courses { context.delete(course) }
        if !courses.isEmpty { changes.formUnion([.courses, .doses]) }

        if diary {
            let entries = fetchAllDiaryEntries()
            let readings = fetchAllBloodPressureReadings()
            photoIds += entries.flatMap(\.photoIds)
            for entry in entries { context.delete(entry) }
            for reading in readings { context.delete(reading) }
            if !entries.isEmpty || !readings.isEmpty { changes.insert(.diary) }
        }

        guard !changes.isEmpty else { return }
        try persistence.commit(changes)
        for id in photoIds { photos.deleteFromDisk(for: id) }
    }
}
