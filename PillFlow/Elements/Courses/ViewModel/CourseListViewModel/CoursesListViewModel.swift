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
        
        // Doses are included deliberately: logging one moves stock, and the rows
        // show it. A needless re-fetch here is cheap; a row left showing a stock
        // count that is no longer true is not.
        NotificationCenter.default.publisher(forDatabaseChanges: [.courses, .doses])
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.fetchCourses() }
            .store(in: &cancellables)
    }
    
    func fetchCourses() {
        let allCourses = dbService.fetchAllCourses()
        let startOfToday = Calendar.current.startOfDay(for: Date())
        
        self.activeCourses = allCourses.filter { Calendar.current.startOfDay(for: $0.endDate) >= startOfToday }

        self.historyCourses = allCourses.filter { Calendar.current.startOfDay(for: $0.endDate) < startOfToday }
            .sorted { $0.endDate > $1.endDate }
    }

    func deleteCourse(_ course: TreatmentCourse) {
        let medicationIds = course.medications.map(\.id)

        guard AppErrorPresenter.shared.run({ try dbService.deleteCourse(course) }) else { return }

        Task { [notificationService] in
            for id in medicationIds {
                await notificationService.cancelNotifications(for: id)
            }
        }
        fetchCourses()
    }
}
