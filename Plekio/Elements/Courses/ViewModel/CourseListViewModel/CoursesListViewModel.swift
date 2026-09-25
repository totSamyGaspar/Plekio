//
//  CoursesListViewModel.swift
//  Plekio
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
    private let courseEditing: CourseEditingUseCaseProtocol
    private let errors: any ErrorReporting
    private var cancellables = Set<AnyCancellable>()
    
    /// `dbService` for reading the list; every write goes through `courseEditing`.
    init(dbService: any CourseStoring, courseEditing: CourseEditingUseCaseProtocol, errors: any ErrorReporting) {
        self.dbService = dbService
        self.courseEditing = courseEditing
        self.errors = errors
        fetchCourses()
        
        // Doses are included deliberately: logging one moves stock, and the rows
        // show it. A needless re-fetch here is cheap; a row left showing a stock
        // count that is no longer true is not.
        NotificationCenter.default.publisher(forDatabaseChanges: [.courses, .doses])
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.fetchCourses() }
            .store(in: &cancellables)
    }
    
    convenience init(dbService: any CourseStoring, notificationService: NotificationServiceProtocol) {
        self.init(
            dbService: dbService,
            courseEditing: CourseEditingUseCase(dbService: dbService, notificationService: notificationService),
            errors: AppErrorPresenter()
        )
    }

    func fetchCourses() {
        let allCourses = dbService.fetchAllCourses()

        self.activeCourses = allCourses.filter { $0.isActive() }
        self.historyCourses = allCourses.filter { !$0.isActive() }
            .sorted { $0.endDate > $1.endDate }
    }

    /// Repeats a finished course: a copy of it with the dates the user picked,
    /// which lands in `activeCourses` as soon as the re-fetch runs. The original
    /// stays in the history untouched. The use case refuses a treatment that is
    /// already running again.
    func repeatCourse(_ course: TreatmentCourse, startDate: Date, endDate: Date) {
        guard let didRepeat = errors.attempt({
            try courseEditing.repeatCourse(course, startDate: startDate, endDate: endDate)
        }), didRepeat else { return }

        fetchCourses()
    }

    /// For the button: whether "Repeat" should be offered at all. Checked on the
    /// list already on screen, so a row costs no fetch; the use case checks again
    /// against storage when the button is pressed.
    func hasActiveRepeat(of course: TreatmentCourse) -> Bool {
        course.hasActiveRepeat(among: activeCourses)
    }

    func deleteCourse(_ course: TreatmentCourse) {
        guard errors.run({ try courseEditing.deleteCourse(course) }) else { return }
        fetchCourses()
    }
}
