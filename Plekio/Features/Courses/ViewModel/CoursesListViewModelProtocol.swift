//
//  CoursesListViewModelProtocol.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI
import Combine

// MARK: - CoursesListViewModelProtocol

@MainActor
protocol CoursesListViewModelProtocol: ObservableObject {
    var activeCourses: [CourseSnapshot] { get }
    var historyCourses: [CourseSnapshot] { get }

    func fetchCourses()
    func repeatCourse(_ course: CourseSnapshot, startDate: Date, endDate: Date)
    func hasActiveRepeat(of course: CourseSnapshot) -> Bool
    func deleteCourse(_ course: CourseSnapshot)
    /// The card's display values, on this screen's clock.
    func row(for course: CourseSnapshot) -> CourseRowViewModel
}
