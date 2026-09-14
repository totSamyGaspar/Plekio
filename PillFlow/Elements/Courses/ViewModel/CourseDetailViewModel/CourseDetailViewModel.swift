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
    
    private let dbService: any CourseStoring
    private let notificationService: NotificationServiceProtocol
    
    init(course: TreatmentCourse, dbService: any CourseStoring, notificationService: NotificationServiceProtocol) {
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
        
        reschedule()
    }
    
    func addNewMedication(_ draft: MedicationDraft) {
        guard AppErrorPresenter.shared.run({
            try dbService.addMedication(draft: draft, to: course)
        }) else { return }
        
        reschedule()
        refreshMedications()
    }
    
    func deleteMedication(at offsets: IndexSet) {
        let toDelete = offsets.map { medications[$0] }
        
        guard AppErrorPresenter.shared.run({
            for med in toDelete {
                try dbService.deleteMedication(med)
            }
        }) else { return }
        
        let deletedIds = toDelete.map(\.id)
        Task { [notificationService] in
            for id in deletedIds {
                await notificationService.cancelNotifications(for: id)
            }
        }
        medications.remove(atOffsets: offsets)
    }
    
    func updateMedication(medication: MedicationItem, with draft: MedicationDraft) {
        guard AppErrorPresenter.shared.run({
            try dbService.updateMedication(medication, with: draft)
        }) else { return }
        
        reschedule()
        refreshMedications()
    }
    
    /// Rebuilding the schedule is asynchronous, and nothing on this screen waits
    /// for it — NotificationService chains overlapping rebuilds itself, so firing
    /// and forgetting is safe here.
    private func reschedule() {
        Task { [notificationService, dbService] in
            await notificationService.rescheduleAll(using: dbService)
        }
    }
    
    private func refreshMedications() {
        medications = course.medications.sorted { $0.name < $1.name }
    }
}
