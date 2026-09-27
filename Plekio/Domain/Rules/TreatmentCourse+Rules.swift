//
//  TreatmentCourse+Rules.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

nonisolated enum CourseRules {

    struct Dates: Equatable {
        let startDate: Date
        let endDate: Date
    }

    /// `day` is the start of the day being displayed, not the current date.
    static func dates(of course: TreatmentCourse, on day: Date) -> Dates {
        let revision = course.dateRevisions
            .filter { $0.validUntil > day }
            .min { $0.validUntil < $1.validUntil }
        return Dates(
            startDate: revision?.startDate ?? course.startDate,
            endDate: revision?.endDate ?? course.endDate
        )
    }

    /// A course ending on `day` is active for the whole of that day.
    static func isActive(endDate: Date, on day: Date, calendar: Calendar) -> Bool {
        calendar.startOfDay(for: endDate) >= calendar.startOfDay(for: day)
    }
}

// MARK: - TreatmentCourse

extension TreatmentCourse {

    func isActive(on day: Date, calendar: Calendar) -> Bool {
        CourseRules.isActive(endDate: endDate, on: day, calendar: calendar)
    }
}
