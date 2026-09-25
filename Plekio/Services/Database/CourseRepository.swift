//
//  CourseRepository.swift
//  Plekio
//
//  Courses for the part of the app that shows and edits them: snapshots out,
//  ids in. No SwiftData type crosses this boundary.
//
//  An adapter over CourseStoring rather than a replacement for it. The
//  reminder planner, the dose schedule and the report builder still read models
//  through CourseStoring — they live in the data layer and never hand a model
//  to a screen. Moving them is a separate step; this one keeps models out of
//  the UI.
//

import Foundation

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

/// A write named a record that is no longer in the store — deleted from another
/// screen while this one still showed it. Thrown rather than ignored, so the
/// user is told instead of watching an edit silently go nowhere.
enum CourseRepositoryError: LocalizedError {
    case notFound

    var errorDescription: String? {
        String(localized: "This item no longer exists. It may have been deleted.")
    }
}

@MainActor
final class SwiftDataCourseRepository: CourseRepository {

    private let store: any CourseStoring

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

    // MARK: - From id back to model

    private func courseModel(_ id: UUID) throws -> TreatmentCourse {
        guard let course = store.fetchCourse(id: id) else { throw CourseRepositoryError.notFound }
        return course
    }

    /// Through the courses: CourseStoring has no fetch by medication id, and a
    /// person has a handful of courses, not thousands.
    private func medicationModel(_ id: UUID) throws -> MedicationItem {
        let medication = store.fetchAllCourses()
            .lazy
            .flatMap(\.medications)
            .first { $0.id == id }
        guard let medication else { throw CourseRepositoryError.notFound }
        return medication
    }
}
