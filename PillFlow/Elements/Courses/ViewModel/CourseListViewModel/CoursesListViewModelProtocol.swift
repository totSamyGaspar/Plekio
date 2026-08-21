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
    func deleteCourse(_ course: TreatmentCourse)
}
