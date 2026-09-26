//
//  DoseBadge.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import Foundation

/// The app-icon count: today's doses whose time has come and that are still open.
/// Skipped doses are settled and never counted.
nonisolated enum DoseBadge {

    // MARK: - Counting

    static func count(of pills: [PillDose], at moment: Date) -> Int {
        pills.filter { $0.status == .pending && $0.time <= moment }.count
    }

    /// The count at `moment`, from that day's doses of `courses`.
    static func count(courses: [TreatmentCourse], at moment: Date, calendar: Calendar) -> Int {
        counts(at: [moment], courses: courses, calendar: calendar)[moment] ?? 0
    }

    /// The count at each moment; each day's doses are built once.
    static func counts(at moments: [Date], courses: [TreatmentCourse], calendar: Calendar) -> [Date: Int] {
        let byDay = Dictionary(grouping: moments) { calendar.startOfDay(for: $0) }
        var result: [Date: Int] = [:]

        for (day, dayMoments) in byDay {
            let pills = DoseDay.pills(of: courses, on: day, calendar: calendar)
            for moment in dayMoments {
                result[moment] = count(of: pills, at: moment)
            }
        }
        return result
    }
}
