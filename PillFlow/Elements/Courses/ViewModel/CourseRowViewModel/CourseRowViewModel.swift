//
//  CourseRowViewModel.swift
//  PillFlow
//
//  Created by Edward Gasparian on 19.05.2026.
//

import Foundation

struct CourseRowViewModel {
    let title: String
    
    let medicationsCount: Int
    
    let dateRangeText: String
    let totalDays: Int
    let currentDayNumber: Int
    let daysProgress: Double

    init(course: TreatmentCourse) {
        self.title = course.name
        self.medicationsCount = course.medications.count
        
        let rangeStart = course.startDate
        let rangeEnd = max(rangeStart, course.endDate)
        self.dateRangeText = rangeStart == rangeEnd
            ? rangeStart.formatted(date: .abbreviated, time: .omitted)
            : (rangeStart ..< rangeEnd).formatted(date: .abbreviated, time: .omitted)

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
