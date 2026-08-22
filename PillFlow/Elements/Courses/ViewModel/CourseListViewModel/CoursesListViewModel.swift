//
//  CoursesListViewModel.swift
//  PillFlow
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI
import Combine

@MainActor
final class CoursesListViewModel: CoursesListViewModelProtocol {
    @Published var activeCourses: [TreatmentCourse] = []
    @Published var historyCourses: [TreatmentCourse] = []
    
    private let dbService: DatabaseServiceProtocol
    private let notificationService: NotificationServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(dbService: DatabaseServiceProtocol, notificationService: NotificationServiceProtocol) {
        self.dbService = dbService
        self.notificationService = notificationService
        fetchCourses()
        
        NotificationCenter.default.publisher(for: .databaseDidUpdate)
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.fetchCourses() }
            .store(in: &cancellables)
    }
    
    func fetchCourses() {
        let allCourses = dbService.fetchAllCourses()
        let startOfToday = Calendar.current.startOfDay(for: Date())
        
        // Active: ending today or in the future
        self.activeCourses = allCourses.filter { Calendar.current.startOfDay(for: $0.endDate) >= startOfToday }

        // History: ended yesterday or earlier (sorted from most recent to oldest)
        self.historyCourses = allCourses.filter { Calendar.current.startOfDay(for: $0.endDate) < startOfToday }
            .sorted { $0.endDate > $1.endDate }
    }

    func deleteCourse(_ course: TreatmentCourse) {
        // Cancel notifications for all medications in this course
        for med in course.medications {
            notificationService.cancelNotifications(for: med.id)
        }

        // Delete the course and refresh the lists
        dbService.deleteCourse(course)
        fetchCourses()
    }
}
