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
        // 1. Сохраняем в БД
        dbService.addMedication(draft: draft, to: course)
        
        // 2. Обновляем пуши
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let activeCourses = dbService.fetchAllCourses().filter { $0.endDate >= Date() }
        notificationService.scheduleNotifications(activeCourses: activeCourses)
        
        // 3. Обновляем локальный список для UI
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
        // 1. Обновляем данные в базе (убедись, что у dbService есть такой метод, если нет — я помогу его написать)
        dbService.updateMedication(medication, with: draft)
        
        // 2. Обновляем пуши
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let activeCourses = dbService.fetchAllCourses().filter { $0.endDate >= Date() }
        notificationService.scheduleNotifications(activeCourses: activeCourses)
        
        // 3. Обновляем локальный список для UI
        self.medications = course.medications.sorted(by: { $0.name < $1.name })
    }
}
