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

    /// What the store held when this screen last read it. Re-read after every
    /// write this screen makes, instead of watching a live model change
    /// underneath it.
    @Published private(set) var course: CourseSnapshot
    @Published private(set) var medications: [MedicationSnapshot]

    @Published var courseName: String
    @Published var startDate: Date
    @Published var endDate: Date

    private let courses: any CourseRepository
    private let courseEditing: CourseEditingUseCaseProtocol
    private let errors: any ErrorReporting

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

    /// Over the SwiftData store, from a model — the shape tests use. The model is
    /// turned into a snapshot here and not kept.
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
    //
    // The screen's part only: hand the edit over, then re-read. Whether a write
    // is needed, the reminders and the lock screen are the use case's.

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
        // Removed locally rather than re-read: the row has to leave with the swipe
        // animation, and the list is exactly what it was minus these rows.
        medications.remove(atOffsets: offsets)
    }

    func updateMedication(medication: MedicationSnapshot, with draft: MedicationDraft) {
        guard errors.run({ try courseEditing.updateMedication(medication, with: draft) }) else { return }
        reload()
    }

    /// Takes the store's current version. The text fields are left alone: they
    /// hold what the user is typing, and the store has just caught up with it.
    private func reload() {
        guard let fresh = courses.course(id: course.id) else { return }
        course = fresh
        medications = fresh.medications
    }
}
