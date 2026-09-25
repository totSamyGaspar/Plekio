//
//  BackgroundReader.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation
import SwiftData

// MARK: - BackgroundReader

/// Long reads on its own ModelContext, off the main actor. Returns values only:
/// models never leave this actor.
@ModelActor
actor BackgroundReader {

    // MARK: - Dose History

    /// Keyed by start of day in `calendar`.
    func pills(onDays days: [Date], calendar: Calendar) throws -> [Date: [PillDose]] {
        let courses = try modelContext.fetch(FetchDescriptor<TreatmentCourse>())

        var result: [Date: [PillDose]] = [:]
        for day in days {
            let start = calendar.startOfDay(for: day)
            result[start] = DoseDay.pills(of: courses, on: start, calendar: calendar)
        }
        return result
    }

    // MARK: - Report

    func reportData(
        for selection: ReportSelection,
        profile: UserProfile,
        calendar: Calendar,
        now: Date
    ) throws -> ReportData {
        ReportAssembler(calendar: calendar, now: now).build(
            selection,
            profile: profile,
            courses: try modelContext.fetch(FetchDescriptor<TreatmentCourse>()),
            pressure: try modelContext.fetch(FetchDescriptor<BloodPressureReading>()),
            diary: try modelContext.fetch(FetchDescriptor<DiaryEntry>())
        )
    }
}
