//
//  CourseRepository.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

// MARK: - CourseRepository

@MainActor
protocol CourseRepository {

    func allCourses() -> [CourseSnapshot]
    func course(id: UUID) -> CourseSnapshot?

    func createCourse(name: String, startDate: Date, endDate: Date, medications: [MedicationDraft]) throws
    func updateCourse(id: UUID, name: String, startDate: Date, endDate: Date) throws
    func duplicateCourse(id: UUID, startDate: Date, endDate: Date) throws
    func deleteCourse(id: UUID) throws

    func addMedication(_ draft: MedicationDraft, toCourse courseId: UUID) throws
    func updateMedication(id: UUID, with draft: MedicationDraft) throws
    func deleteMedication(id: UUID) throws
    func refillStock(medicationId: UUID, amount: Int) throws
}

// MARK: - CourseRepositoryError

/// The record was deleted elsewhere; thrown so an edit never silently goes nowhere.
enum CourseRepositoryError: LocalizedError {
    case notFound

    var errorDescription: String? {
        String(localized: "This item no longer exists. It may have been deleted.")
    }
}

// MARK: - SwiftDataCourseRepository

@MainActor
final class SwiftDataCourseRepository: CourseRepository {

    // MARK: - Properties

    private let store: any CourseStoring

    // MARK: - Init

    init(store: any CourseStoring) {
        self.store = store
    }

    // MARK: - Reading

    func allCourses() -> [CourseSnapshot] {
        store.fetchAllCourses().map { CourseSnapshot($0) }
    }

    func course(id: UUID) -> CourseSnapshot? {
        store.fetchCourse(id: id).map { CourseSnapshot($0) }
    }

    // MARK: - Writing

    func createCourse(name: String, startDate: Date, endDate: Date, medications: [MedicationDraft]) throws {
        try store.saveCourse(name: name, startDate: startDate, endDate: endDate, drafts: medications)
    }

    func updateCourse(id: UUID, name: String, startDate: Date, endDate: Date) throws {
        try store.updateCourseDetails(course: try courseModel(id), name: name, startDate: startDate, endDate: endDate)
    }

    func duplicateCourse(id: UUID, startDate: Date, endDate: Date) throws {
        try store.duplicateCourse(try courseModel(id), startDate: startDate, endDate: endDate)
    }

    func deleteCourse(id: UUID) throws {
        try store.deleteCourse(try courseModel(id))
    }

    func addMedication(_ draft: MedicationDraft, toCourse courseId: UUID) throws {
        try store.addMedication(draft: draft, to: try courseModel(courseId))
    }

    func updateMedication(id: UUID, with draft: MedicationDraft) throws {
        try store.updateMedication(try medicationModel(id), with: draft)
    }

    func deleteMedication(id: UUID) throws {
        try store.deleteMedication(try medicationModel(id))
    }

    func refillStock(medicationId: UUID, amount: Int) throws {
        try store.refillStock(for: try medicationModel(medicationId), amount: amount)
    }

    // MARK: - Model Lookup

    private func courseModel(_ id: UUID) throws -> TreatmentCourse {
        guard let course = store.fetchCourse(id: id) else { throw CourseRepositoryError.notFound }
        return course
    }

    /// Scans courses: CourseStoring has no fetch by medication id, and courses are few.
    private func medicationModel(_ id: UUID) throws -> MedicationItem {
        let medication = store.fetchAllCourses()
            .lazy
            .flatMap(\.medications)
            .first { $0.id == id }
        guard let medication else { throw CourseRepositoryError.notFound }
        return medication
    }
}
