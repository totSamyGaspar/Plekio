//
//  CourseRowViewModel.swift
//  PillFlow
//
//  Created by Edward Gasparian on 19.05.2026.
//

import Foundation

//struct CourseRowViewModel: CourseRowViewModelProtocol {
//    private let course: TreatmentCourse
//
//    init(course: TreatmentCourse) {
//        self.course = course
//    }
//
//    var title: String {
//        course.name
//    }
//
//    var medicationsCountText: String {
//        "Medications: \(course.medications.count)"
//    }
//
//    var dateRangeText: String {
//        "\(course.startDate.formatted(date: .abbreviated, time: .omitted)) - \(course.endDate.formatted(date: .abbreviated, time: .omitted))"
//    }
//
//    var totalDays: Int {
//        let calendar = Calendar.current
//        let start = calendar.startOfDay(for: course.startDate)
//        let end = calendar.startOfDay(for: course.endDate)
//        let components = calendar.dateComponents([.day], from: start, to: end)
//        return (components.day ?? 0) + 1
//    }
//
//    var currentDayNumber: Int {
//        let calendar = Calendar.current
//        let start = calendar.startOfDay(for: course.startDate)
//        let today = calendar.startOfDay(for: Date())
//
//        if today < start { return 0 }
//
//        let components = calendar.dateComponents([.day], from: start, to: today)
//        let daysPassed = (components.day ?? 0) + 1
//
//        return min(daysPassed, totalDays)
//    }
//
//    var daysProgress: Double {
//        guard totalDays > 0 else { return 0 }
//        return Double(currentDayNumber) / Double(totalDays)
//    }
//}

struct CourseRowViewModel: CourseRowViewModelProtocol {
    let title: String
    let medicationsCountText: String
    let dateRangeText: String
    let totalDays: Int
    let currentDayNumber: Int
    let daysProgress: Double

    init(course: TreatmentCourse) {
        self.title = course.name
        self.medicationsCountText = "Medications: \(course.medications.count)"
        self.dateRangeText =
            "\(course.startDate.formatted(date: .abbreviated, time: .omitted)) - \(course.endDate.formatted(date: .abbreviated, time: .omitted))"

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: course.startDate)
        let end = calendar.startOfDay(for: course.endDate)
        let total =
            (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        self.totalDays = total

        let today = calendar.startOfDay(for: Date())
        if today < start {
            self.currentDayNumber = 0
        } else {
            let components = calendar.dateComponents(
                [.day],
                from: start,
                to: today
            )
            let daysPassed = (components.day ?? 0) + 1
            self.currentDayNumber = min(daysPassed, total)
        }

        self.daysProgress =
            total > 0 ? Double(self.currentDayNumber) / Double(total) : 0
    }
}
