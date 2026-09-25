//
//  TreatmentCourse+Rules.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

nonisolated enum CourseRules {

    /// A course ending on `day` is active for the whole of that day.
    static func isActive(endDate: Date, on day: Date, calendar: Calendar) -> Bool {
        calendar.startOfDay(for: endDate) >= calendar.startOfDay(for: day)
    }
}

// MARK: - TreatmentCourse

extension TreatmentCourse {

    func isActive(on day: Date = Date(), calendar: Calendar = .current) -> Bool {
        CourseRules.isActive(endDate: endDate, on: day, calendar: calendar)
    }
}
