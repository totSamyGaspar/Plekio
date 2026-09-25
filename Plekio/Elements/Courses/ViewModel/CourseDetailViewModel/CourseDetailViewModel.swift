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
    @Published var course: TreatmentCourse
    @Published var medications: [MedicationItem]
    
    @Published var courseName: String
    @Published var startDate: Date
    @Published var endDate: Date
    
    private let courseEditing: CourseEditingUseCaseProtocol

    init(course: TreatmentCourse, courseEditing: CourseEditingUseCaseProtocol) {
        self.course = course
        self.courseEditing = courseEditing

        self.courseName = course.name
        self.startDate = course.startDate
        self.endDate = course.endDate

        self.medications = course.medications.sorted(by: { $0.name < $1.name })
    }

    /// Builds the default use case from the two services, so tests can keep
    /// constructing the screen from mocks of those.
    convenience init(course: TreatmentCourse, dbService: any CourseStoring, notificationService: NotificationServiceProtocol) {
        self.init(
            course: course,
            courseEditing: CourseEditingUseCase(dbService: dbService, notificationService: notificationService)
        )
    }

    // MARK: - Actions
    //
    // The screen's part only: hand the edit over, then refresh the list. Whether
    // a write is needed, the reminders and the lock screen are the use case's.

    func saveCourseChanges() {
        AppErrorPresenter.shared.run {
            _ = try courseEditing.updateDetails(of: course, name: courseName, startDate: startDate, endDate: endDate)
        }
    }

    func addNewMedication(_ draft: MedicationDraft) {
        guard AppErrorPresenter.shared.run({ try courseEditing.addMedication(draft, to: course) }) else { return }
        refreshMedications()
    }

    func deleteMedication(at offsets: IndexSet) {
        let toDelete = offsets.map { medications[$0] }
        guard AppErrorPresenter.shared.run({ try courseEditing.deleteMedications(toDelete) }) else { return }
        medications.remove(atOffsets: offsets)
    }

    func updateMedication(medication: MedicationItem, with draft: MedicationDraft) {
        guard AppErrorPresenter.shared.run({ try courseEditing.updateMedication(medication, with: draft) }) else { return }
        refreshMedications()
    }

    private func refreshMedications() {
        medications = course.medications.sorted { $0.name < $1.name }
    }
}
