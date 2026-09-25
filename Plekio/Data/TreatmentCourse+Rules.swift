//
//  TreatmentCourse+Rules.swift
//  Plekio
//
//  Domain rules about a course, in one place. "Is this course still running"
//  was written out by hand in the notification service, the course list and
//  the statistics — three copies of a rule that decides which reminders fire.
//

import Foundation

extension TreatmentCourse {

    /// Still running on `day`: it ends today or later. A course ending today is
    /// active for the whole of today.
    func isActive(on day: Date = Date(), calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: endDate) >= calendar.startOfDay(for: day)
    }

    /// Whether this treatment is already running again — the course itself or
    /// any copy of it is among `activeCourses`. Matched on the repeat lineage,
    /// not on the name, so a renamed copy still counts.
    func hasActiveRepeat(among activeCourses: [TreatmentCourse]) -> Bool {
        let lineage = repeatLineageId
        return activeCourses.contains { $0.repeatLineageId == lineage }
    }
}
