//
//  CoursesListViewModelProtocol.swift
//  PillFlow
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI
import Combine

@MainActor
protocol CoursesListViewModelProtocol: ObservableObject {
    var activeCourses: [TreatmentCourse] { get }
    var historyCourses: [TreatmentCourse] { get }
    
    func fetchCourses()
    func repeatCourse(_ course: TreatmentCourse, startDate: Date, endDate: Date)
    func hasActiveRepeat(of course: TreatmentCourse) -> Bool
    func deleteCourse(_ course: TreatmentCourse)
}
