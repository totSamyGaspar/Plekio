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

    // MARK: - Properties

    @Published var activeCourses: [CourseSnapshot] = []
    @Published var historyCourses: [CourseSnapshot] = []

    private let courses: any CourseRepository
    private let courseEditing: CourseEditingUseCaseProtocol
    private let errors: any ErrorReporting
    private let time: any TimeSource
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    /// `courses` for reading the list; every write goes through `courseEditing`.
    init(
        courses: any CourseRepository,
        courseEditing: CourseEditingUseCaseProtocol,
        errors: any ErrorReporting,
        changes: DatabaseChangeFeed,
        time: any TimeSource = SystemTime()
    ) {
        self.time = time
        self.courses = courses
        self.courseEditing = courseEditing
        self.errors = errors
        fetchCourses()

        // Doses included: logging one changes stock shown in the rows.
        changes.publisher(for: [.courses, .doses])
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.fetchCourses() }
            .store(in: &cancellables)
    }

    convenience init(dbService: any CourseStoring & DatabaseChangeSource, notificationService: NotificationServiceProtocol) {
        let courses = SwiftDataCourseRepository(store: dbService)
        self.init(
            courses: courses,
            courseEditing: CourseEditingUseCase(courses: courses, notificationService: notificationService),
            errors: AppErrorPresenter(),
            changes: dbService.changes
        )
    }

    // MARK: - Actions

    func fetchCourses() {
        let allCourses = courses.allCourses()

        let now = time.now
        let calendar = time.calendar
        self.activeCourses = allCourses.filter { $0.isActive(on: now, calendar: calendar) }
        self.historyCourses = allCourses.filter { !$0.isActive(on: now, calendar: calendar) }
            .sorted { $0.endDate > $1.endDate }
    }

    /// Copies the course with new dates; the original stays in history. The use
    /// case refuses if the treatment is already running again.
    @discardableResult
    func repeatCourse(_ course: CourseSnapshot, startDate: Date, endDate: Date) -> Bool {
        guard let didRepeat = errors.attempt({
            try courseEditing.repeatCourse(course, startDate: startDate, endDate: endDate)
        }), didRepeat else { return false }

        fetchCourses()
        return true
    }

    /// Checked against the on-screen list; the use case re-checks storage on repeat.
    func hasActiveRepeat(of course: CourseSnapshot) -> Bool {
        course.hasActiveRepeat(among: activeCourses)
    }

    @discardableResult
    func deleteCourse(_ course: CourseSnapshot) -> Bool {
        guard errors.run({ try courseEditing.deleteCourse(course) }) else { return false }
        fetchCourses()
        return true
    }

    func row(for course: CourseSnapshot) -> CourseRowViewModel {
        CourseRowViewModel(course: course, time: time)
    }
}
