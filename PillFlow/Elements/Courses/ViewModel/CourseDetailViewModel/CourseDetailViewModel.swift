//
//  CourseDetailViewModel.swift
//  PillFlow
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
    
    private let dbService: DatabaseServiceProtocol
    private let notificationService: NotificationServiceProtocol
    
    init(course: TreatmentCourse, dbService: DatabaseServiceProtocol, notificationService: NotificationServiceProtocol) {
        self.course = course
        self.dbService = dbService
        self.notificationService = notificationService
        
        self.courseName = course.name
        self.startDate = course.startDate
        self.endDate = course.endDate
        
        self.medications = course.medications.sorted(by: { $0.name < $1.name })
    }
    
    func saveCourseChanges() {
        guard course.name != courseName
                || course.startDate != startDate
                || course.endDate != endDate
        else { return }

        guard AppErrorPresenter.shared.run({
            try dbService.updateCourseDetails(course: course, name: courseName, startDate: startDate, endDate: endDate)
        }) else { return }

        notificationService.rescheduleAll(using: dbService)
    }

    func addNewMedication(_ draft: MedicationDraft) {
        guard AppErrorPresenter.shared.run({
            try dbService.addMedication(draft: draft, to: course)
        }) else { return }

        notificationService.rescheduleAll(using: dbService)
        refreshMedications()
    }

    func deleteMedication(at offsets: IndexSet) {
        let toDelete = offsets.map { medications[$0] }

        guard AppErrorPresenter.shared.run({
            for med in toDelete {
                try dbService.deleteMedication(med)
            }
        }) else { return }

        for med in toDelete {
            notificationService.cancelNotifications(for: med.id)
        }
        medications.remove(atOffsets: offsets)
    }

    func updateMedication(medication: MedicationItem, with draft: MedicationDraft) {
        guard AppErrorPresenter.shared.run({
            try dbService.updateMedication(medication, with: draft)
        }) else { return }

        notificationService.rescheduleAll(using: dbService)
        refreshMedications()
    }

    private func refreshMedications() {
        medications = course.medications.sorted { $0.name < $1.name }
    }
}
