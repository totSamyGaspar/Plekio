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
        dbService.updateCourseDetails(course: course, name: courseName, startDate: startDate, endDate: endDate)
    }
    
    func addNewMedication(_ draft: MedicationDraft) {
        // 1. Persist to the database
        dbService.addMedication(draft: draft, to: course)

        // 2. Reschedule notifications (via the protocol, not directly through UNUserNotificationCenter)
        notificationService.removeAllPending()
        let activeCourses = dbService.fetchAllCourses().filter { $0.endDate >= Date() }
        notificationService.scheduleNotifications(activeCourses: activeCourses)

        // 3. Refresh the local list for the UI
        self.medications = course.medications.sorted(by: { $0.name < $1.name })
    }
    
    func deleteMedication(at offsets: IndexSet) {
        for index in offsets {
            let med = medications[index]
            notificationService.cancelNotifications(for: med.id)
            dbService.deleteMedication(med)
        }
        medications.remove(atOffsets: offsets)
    }
    
    func updateMedication(medication: MedicationItem, with draft: MedicationDraft) {
        // 1. Persist changes to the database
        dbService.updateMedication(medication, with: draft)

        // 2. Reschedule notifications (via the protocol, not directly through UNUserNotificationCenter)
        notificationService.removeAllPending()
        let activeCourses = dbService.fetchAllCourses().filter { $0.endDate >= Date() }
        notificationService.scheduleNotifications(activeCourses: activeCourses)

        // 3. Refresh the local list for the UI
        self.medications = course.medications.sorted(by: { $0.name < $1.name })
    }
}
