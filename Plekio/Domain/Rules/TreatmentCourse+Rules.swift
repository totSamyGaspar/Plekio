//
//  TreatmentCourse+Rules.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

nonisolated enum CourseRules {

    struct Days: Equatable {
        let start: LocalDay
        let end: LocalDay
    }

    /// The course's days as they stood on `day`: an edit applies from its own day on.
    static func days(of course: TreatmentCourse, on day: LocalDay) -> Days {
        let revision = course.dateRevisions
            .filter { $0.validUntilDay > day }
            .min { $0.validUntilDay < $1.validUntilDay }
        return Days(start: revision?.startDay ?? course.startDay, end: revision?.endDay ?? course.endDay)
    }

    /// A course ending on `day` is active for the whole of that day.
    static func isActive(endDate: Date, on day: Date, calendar: Calendar) -> Bool {
        calendar.startOfDay(for: endDate) >= calendar.startOfDay(for: day)
    }
}

// MARK: - TreatmentCourse

extension TreatmentCourse {

    func isActive(on day: Date, calendar: Calendar) -> Bool {
        endDay >= LocalDay(day, in: calendar)
    }
}
