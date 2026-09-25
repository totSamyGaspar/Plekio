//
//  CoursesListViewModelProtocol.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI
import Combine

@MainActor
protocol CoursesListViewModelProtocol: ObservableObject {
    var activeCourses: [CourseSnapshot] { get }
    var historyCourses: [CourseSnapshot] { get }
    
    func fetchCourses()
    func repeatCourse(_ course: CourseSnapshot, startDate: Date, endDate: Date)
    func hasActiveRepeat(of course: CourseSnapshot) -> Bool
    func deleteCourse(_ course: CourseSnapshot)
}
