//
//  TreatmentCourse+Rules.swift
//  Plekio
//
//  Domain rules about a course, in one place. "Is this course still running"
//  was written out by hand in the notification service, the course list and
//  the statistics — three copies of a rule that decides which reminders fire.
//  Both the model and CourseSnapshot answer it through CourseRules.
//

import Foundation

nonisolated enum CourseRules {

    /// Still running on `day`: it ends today or later. A course ending today is
    /// active for the whole of today.
    static func isActive(endDate: Date, on day: Date, calendar: Calendar) -> Bool {
        calendar.startOfDay(for: endDate) >= calendar.startOfDay(for: day)
    }
}

extension TreatmentCourse {

    func isActive(on day: Date = Date(), calendar: Calendar = .current) -> Bool {
        CourseRules.isActive(endDate: endDate, on: day, calendar: calendar)
    }
}
