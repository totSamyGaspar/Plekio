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

    /// `days(of:on:)` as midnights where the person is now, for screens and the report.
    /// `day` is the start of the day being displayed, not the current date.
    static func dates(of course: TreatmentCourse, on day: Date) -> Dates {
        let calendar = Calendar.autoupdatingCurrent
        let days = days(of: course, on: LocalDay(day, in: calendar))
        return Dates(startDate: days.start.start(in: calendar), endDate: days.end.start(in: calendar))
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
