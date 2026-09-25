//
//  CourseDetailViewModel.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI
import Combine

@MainActor
final class CourseDetailViewModel: CourseDetailViewModelProtocol {

    // MARK: - Properties

    /// Last-read store state; reloaded after each write rather than observed live.
    @Published private(set) var course: CourseSnapshot
    @Published private(set) var medications: [MedicationSnapshot]

    @Published var courseName: String
    @Published var startDate: Date
    @Published var endDate: Date

    private let courses: any CourseRepository
    private let courseEditing: CourseEditingUseCaseProtocol
    private let errors: any ErrorReporting

    // MARK: - Init

    init(
        course: CourseSnapshot,
        courses: any CourseRepository,
        courseEditing: CourseEditingUseCaseProtocol,
        errors: any ErrorReporting
    ) {
        self.course = course
        self.courses = courses
        self.courseEditing = courseEditing
        self.errors = errors

        self.courseName = course.name
        self.startDate = course.startDate
        self.endDate = course.endDate
        self.medications = course.medications
    }

    /// Builds the SwiftData-backed stack from a model; used by tests.
    convenience init(course: TreatmentCourse, dbService: any CourseStoring, notificationService: NotificationServiceProtocol) {
        let courses = SwiftDataCourseRepository(store: dbService)
        self.init(
            course: CourseSnapshot(course),
            courses: courses,
            courseEditing: CourseEditingUseCase(courses: courses, notificationService: notificationService),
            errors: AppErrorPresenter()
        )
    }

    // MARK: - Actions

    func saveCourseChanges() {
        guard let wrote = errors.attempt({
            try courseEditing.updateDetails(of: course, name: courseName, startDate: startDate, endDate: endDate)
        }), wrote else { return }
        reload()
    }

    func addNewMedication(_ draft: MedicationDraft) {
        guard errors.run({ try courseEditing.addMedication(draft, to: course) }) else { return }
        reload()
    }

    func deleteMedication(at offsets: IndexSet) {
        let toDelete = offsets.map { medications[$0] }
        guard errors.run({ try courseEditing.deleteMedications(toDelete) }) else { return }
        // Removed locally, not reloaded, so the swipe-delete animation plays.
        medications.remove(atOffsets: offsets)
    }

    func updateMedication(medication: MedicationSnapshot, with draft: MedicationDraft) {
        guard errors.run({ try courseEditing.updateMedication(medication, with: draft) }) else { return }
        reload()
    }

    // MARK: - Private

    /// Leaves the editable fields alone: they hold the user's in-progress input.
    private func reload() {
        guard let fresh = courses.course(id: course.id) else { return }
        course = fresh
        medications = fresh.medications
    }
}
