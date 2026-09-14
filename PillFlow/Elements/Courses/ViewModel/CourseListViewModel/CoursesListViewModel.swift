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
    
    private let dbService: any CourseStoring
    private let notificationService: NotificationServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(dbService: any CourseStoring, notificationService: NotificationServiceProtocol) {
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
    
    /// Repeats a finished course: a copy of it with the dates the user picked,
    /// which lands in `activeCourses` as soon as the re-fetch runs. The original
    /// stays in the history untouched.
    func repeatCourse(_ course: TreatmentCourse, startDate: Date, endDate: Date) {

        guard !hasActiveRepeat(of: course) else { return }
        
        guard AppErrorPresenter.shared.run({
            try dbService.duplicateCourse(course, startDate: startDate, endDate: endDate)
        }) else { return }
        
        Task { [notificationService, dbService] in
            await notificationService.rescheduleAll(using: dbService)
        }
        fetchCourses()
    }
    
    /// Whether this treatment is already running again — the course itself or any
    /// copy of it is among the active ones.
    func hasActiveRepeat(of course: TreatmentCourse) -> Bool {
        let lineage = course.repeatLineageId
        return activeCourses.contains { $0.repeatLineageId == lineage }
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
